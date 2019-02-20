#!/usr/bin/env python3
#
# Simple script to add all removed/deprecated binary RPMs to PES
#
# Copyright (c) 2018 Tomas Hozza <thozza@redhat.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import re
import sys
import logging
import subprocess
import argparse

import yaml
import jinja2


log = logging.getLogger(__name__)
log.setLevel(logging.INFO)
log.addHandler(logging.StreamHandler())


class Brew:
    """
    Commands related to interacting with Brew.
    """

    LATEST_BUILD_TARGET = {
        "rhel-7": "rhel-7.6-candidate",
        "rhel-8": "rhel-8.0.0-candidate"
    }

    @staticmethod
    def get_latest_build_nvr_in_release(pkg_name, release='rhel-7'):
        """
        Get the latest existing build NVR for specific package in specific RHEL release and extract the version from it.
        """
        brew_output_raw = subprocess.check_output(
            ["brew", "latest-build", "--quiet", Brew.LATEST_BUILD_TARGET[release], pkg_name]).decode()
        if not len(brew_output_raw):
            log.debug("Didn't find any latest build of '%s' for '%s'", pkg_name, Brew.LATEST_BUILD_TARGET[release])
            return None
        latest_nvr = brew_output_raw.split()[0]
        log.debug("Found latest build of '%s' for '%s': '%s'", pkg_name, Brew.LATEST_BUILD_TARGET[release], latest_nvr)
        return latest_nvr

    @staticmethod
    def get_rpms_for_srpm(nvr, names_only=True, arch=None, filter_debuginfo=True):
        """
        ...
        """
        rpms = list()

        if not nvr:
            return rpms

        if arch is None:
            arch = ["x86_64", "noarch"]

        brew_output_raw = subprocess.check_output(
            ["brew", "buildinfo", nvr]
        ).decode()
        if not len(brew_output_raw):
            raise ValueError("Can not find build info for NVR '%s' from Brew" % nvr)

        splitted_nvr = nvr.split("-")
        pattern_raw = r"/mnt/redhat/brewroot/packages/{name}/{version}/{release}/(?:{arch})/(?P<rpm>.*.rpm)"
        pattern = pattern_raw.format(
            name="-".join(splitted_nvr[:-2]),
            version=splitted_nvr[-2],
            release=splitted_nvr[-1],
            arch="|".join(arch)
        )
        log.debug("Using '{}' regular expression to match built RPMs".format(pattern))
        pattern_compiled = re.compile(pattern, re.MULTILINE)

        for line in brew_output_raw.split("\n"):
            match = pattern_compiled.search(line)
            if match is not None:
                rpms.append(match.group("rpm"))
        log.debug("Gathered the following binary RPMs for '%s' arches: %s", arch, rpms)

        if names_only:
            rpms = ["-".join(x.split("-")[:-2]) for x in rpms]

        if filter_debuginfo:
            rpms = [x for x in rpms if x.find("-debuginfo") == -1]

        return rpms


class Pes:
    """
    Commands related to interacting with PES.
    """
    ACTION_REMOVAL = "1"
    ACTION_DEPRECATION = "2"
    ACTION_REPLACEMENT = "3"
    ACTION_SPLIT = "4"
    ACTION_MERGE = "5"
    ACTION_MOVE = "6"
    ACTION_RENAME = "7"

    TEST_INSTANCE_URL = "https://pes.dev.leapp.lab.eng.brq.redhat.com"

    RELEASE_RHEL_8_0 = "RHEL 8.0"

    def __init__(self, url=None, dry_run=False):
        self.url = url
        self.dry_run = dry_run

    def _add_event_rpm(self, event_action, rpm_name, title, internal_notes, release_notes=None, migration_notes=None,
                       link=None, release=None):
        """
        Add the given type of event into PES for provided binary RPM.
        """
        pes_cmd = ["pes-cli", "event", "new"]
        if self.url:
            pes_cmd.extend(["-u", self.url])
        pes_cmd.extend(
            ["--action", event_action,
             "--in-package", rpm_name,
             "--internal-notes", internal_notes,
             "--title", title]
        )
        if release_notes:
            pes_cmd.extend(["--release-notes", release_notes])
        if migration_notes:
            pes_cmd.extend(["--migration-notes", migration_notes])
        if link:
            pes_cmd.extend(["--link", link])
        if release:
            pes_cmd.extend(["--release", release])
        else:
            pes_cmd.extend(["--release", self.RELEASE_RHEL_8_0])

        if not self.dry_run:
            log.debug("Running pes-cli command: '%s'", " ".join(pes_cmd))
            try:
                _ = subprocess.check_output(pes_cmd).decode()
            except subprocess.CalledProcessError as e:
                log.warning("Adding of event '%s' for package '%s' failed due to error: '%s'", event_action, rpm_name,
                            e.output.decode())
            else:
                log.info("Successfully added new event '%s' for package '%s'", event_action, rpm_name)
        else:
            log.info("[dry run] Would run pes-cli command: '%s'", " ".join(pes_cmd))

    def _add_event_srpm(self, event_action, srpm_name, title, internal_notes, release_notes=None, migration_notes=None,
                        link=None, release=None):
        """
        Add the given type of event into PES for every binary RPM, which is built from the provided SRPM. The same notes
        and information provided as arguments is used for every binary RPM. Brew is used for SRPM -> RPM mapping.
        """
        # for now we use latest RHEL-7 builds for determining which RPMs where removed from RHEL-8
        latest_build = Brew.get_latest_build_nvr_in_release(srpm_name)
        rpms = Brew.get_rpms_for_srpm(latest_build)

        log.debug("In _add_event_srpm. Found RPMs: %s", rpms)

        for rpm in rpms:
            self._add_event_rpm(event_action, rpm, title, internal_notes, release_notes, migration_notes, link,
                                release)

    def add_removed_rpm(self, rpm_name, title, internal_notes, release_notes=None, migration_notes=None, link=None,
                        release=None):
        """
        Add REMOVAL event into PES for provided binary RPM.
        """
        self._add_event_rpm(self.ACTION_REMOVAL, rpm_name, title, internal_notes, release_notes, migration_notes, link,
                            release)

    def add_removed_srpm(self, srpm_name, title, internal_notes, release_notes=None, migration_notes=None, link=None,
                         release=None):
        """
        Add REMOVAL event into PES for every binary RPM, which is built from the provided SRPM. The same notes and
        information provided as arguments is used for every binary RPM.
        """
        self._add_event_srpm(
            self.ACTION_REMOVAL,
            srpm_name,
            title,
            internal_notes,
            release_notes,
            migration_notes,
            link,
            release
        )

    def add_deprecated_rpm(self, rpm_name, title, internal_notes, release_notes=None, migration_notes=None, link=None,
                           release=None):
        """
        Add DEPRECATION event into PES for provided binary RPM.
        """
        self._add_event_rpm(self.ACTION_DEPRECATION, rpm_name, title, internal_notes, release_notes, migration_notes,
                            link, release)

    def add_deprecated_srpm(self, srpm_name, title, internal_notes, release_notes=None, migration_notes=None, link=None,
                            release=None):
        """
        Add DEPRECATION event into PES for every binary RPM, which is built from the provided SRPM. The same notes and
        information provided as arguments is used for every binary RPM.
        """
        self._add_event_srpm(
            self.ACTION_DEPRECATION,
            srpm_name,
            title,
            internal_notes,
            release_notes,
            migration_notes,
            link,
            release
        )


def base_pes_action(rpm_action, srpm_action, changes):
    """
    Common part of all PES interactions. Basically the Core of the whole script.

    :param rpm_action: callable function to call for changes on RPM level.
    :param srpm_action: callable function to call for changes on SRPM level.
    :param changes: changes read from YAML file, including default values
    :return: None
    """
    default_title = changes.get("default_title", None)
    default_internal_notes = changes.get("default_internal_notes", None)
    default_release_notes = changes.get("default_release_notes", None)
    default_migration_notes = changes.get("default_migration_notes", None)
    default_link = changes.get("default_link", None)

    default_release = changes.get("default_release", "RHEL 8.0")
    default_srpm_names = changes.get("default_srpm_names", True)

    for event in changes.get("changes", list()):
        try:
            packages = event["package"]
        except KeyError:
            log.error("Encountered an event without 'packages' element, which is MANDATORY, skipping...")
            continue

        if isinstance(packages, str):
            packages = [packages]

        title = event.get("title", default_title)
        internal_notes = event.get("internal_notes", default_internal_notes)
        release_notes = event.get("release_notes", default_release_notes)
        migration_notes = event.get("migration_notes", default_migration_notes)
        link = event.get("link", default_link)
        release = event.get("release", default_release)
        srpm_names = event.get("srpm_names", default_srpm_names)

        # add events for each package
        for package in packages:
            # first replace all possible variables
            title = jinja2.Environment(loader=jinja2.BaseLoader).from_string(title).render(
                package=package,
                release=release
            )
            internal_notes = jinja2.Environment(loader=jinja2.BaseLoader).from_string(internal_notes).render(
                package=package,
                release=release
            )
            if release_notes is not None:
                release_notes = jinja2.Environment(loader=jinja2.BaseLoader).from_string(release_notes).render(
                    package=package,
                    release=release
                )
            if migration_notes is not None:
                migration_notes = jinja2.Environment(loader=jinja2.BaseLoader).from_string(migration_notes).render(
                    package=package,
                    release=release
                )
            if link is not None:
                link = jinja2.Environment(loader=jinja2.BaseLoader).from_string(link).render(
                    package=package,
                    release=release
                )

            if srpm_names:
                func = srpm_action
            else:
                func = rpm_action

            func(package, title, internal_notes, release_notes, migration_notes, link, release)


def add_removals_to_pes(pes_instance, changes):
    base_pes_action(pes_instance.add_removed_rpm, pes_instance.add_removed_srpm, changes)


def add_deprecations_to_pes(pes_instance, changes):
    base_pes_action(pes_instance.add_deprecated_rpm, pes_instance.add_deprecated_srpm, changes)


def get_argparser():
    """
    Create arguments parser and return it.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-d", "--debug",
        action="store_true",
        default=False,
        help="Turn on more verbose logging."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Don't execute any pes-cli commands, just print what would be executed."
    )
    parser.add_argument(
        "-t", "--test",
        action="store_true",
        default=False,
        help="Use testing instance of PES (for testing)."
    )
    subparsers = parser.add_subparsers(
        title="commands",
        dest="command",
    )
    subparsers.required = True

    parser_removed = subparsers.add_parser("removed")
    parser_removed.set_defaults(func=add_removals_to_pes)

    parser_deprecated = subparsers.add_parser("deprecated")
    parser_deprecated.set_defaults(func=add_deprecations_to_pes)

    for p in (parser_removed, parser_deprecated):
        p.add_argument(
            "changes_file",
            help="YAML file with described changes to add PES. (default is 'pes_changes.yaml')"
        )

    return parser


def get_events_from_yaml(file):
    """
    Read the list of changes and values from the YAML file and return it.
    """
    with open(file, "r") as f:
        changes = yaml.safe_load(f.read())
    return changes


def main(args):
    arg_parser = get_argparser()
    options = arg_parser.parse_args(args[1:])
    if options.debug:
        log.setLevel(logging.DEBUG)
    log.debug(options)

    changes = get_events_from_yaml(options.changes_file)

    dry_run = options.dry_run

    if options.test:
        pes = Pes(Pes.TEST_INSTANCE_URL, dry_run=dry_run)
        log.debug("Using testing instance of PES %s", Pes.TEST_INSTANCE_URL)
    else:
        pes = Pes(dry_run=dry_run)

    options.func(pes, changes)


if __name__ == "__main__":
    try:
        main(sys.argv)
    except KeyboardInterrupt:
        log.info("Interrupted by user...")

