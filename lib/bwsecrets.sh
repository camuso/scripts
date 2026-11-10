#!/bin/bash
#
# bwsecrets.sh - Bitwarden access for ~/bin scripts
#
# Tokens stay in the Bitwarden vault. A script unlocks the vault, which
# prompts for the master password, and reads an item into a variable.
# Nothing in this file prints a token, a master password, a Send password,
# or a session key.
#
# Vault item names:
#   github-token      GitHub personal access token
#   gitlab-token      gitlab.com personal access token
#   gitlab-cee-token  gitlab.cee.redhat.com personal access token
#
# Provisioning copies those tokens with a password-protected Bitwarden Send.
# The Send URL is itself a secret. Callers must not log it.

# Item names are fixed so every script looks up the same records.
BW_ITEM_GITHUB="github-token"
BW_ITEM_GITLAB="gitlab-token"
BW_ITEM_GITLAB_CEE="gitlab-cee-token"

# Set when this process unlocked the vault and therefore must lock it.
BW_UNLOCKED_HERE="${BW_UNLOCKED_HERE:-no}"

#** secret_runtime_dir: private directory for short-lived secret files
#*
secret_runtime_dir() {
	local dir="${XDG_RUNTIME_DIR:-}"

	if [[ -z "$dir" || ! -d "$dir" || ! -w "$dir" ]]; then
		dir="/dev/shm"
	fi
	if [[ ! -d "$dir" || ! -w "$dir" ]]; then
		dir="$HOME/.cache"
		mkdir -p "$dir"
		chmod 700 "$dir"
	fi
	printf '%s\n' "$dir"
}

#** secret_tmp: mode-0600 temporary file
#*
secret_tmp() {
	local dir file

	dir="$(secret_runtime_dir)"
	file="$(mktemp "$dir/bwsecret.XXXXXX")" || return 1
	chmod 600 "$file"
	printf '%s\n' "$file"
}

#** secret_shred: remove files that held secrets
#*
secret_shred() {
	local file

	for file in "$@"; do
		[[ -n "$file" && -f "$file" ]] || continue
		shred -u "$file" 2>/dev/null || rm -f "$file"
	done
}

#** bw_bin: print the bw executable path
#*
bw_bin() {
	if command -v bw >/dev/null 2>&1; then
		command -v bw
		return 0
	fi
	if [[ -x "$HOME/.local/bin/bw" ]]; then
		printf '%s\n' "$HOME/.local/bin/bw"
		return 0
	fi
	return 1
}

#** bw_require: install the official CLI when it is missing
#*
# Downloads the current Linux build from Bitwarden and checks the
# SHA-256 published on the GitHub release. Installs into ~/.local/bin.
#*
bw_require() {
	local bw

	export PATH="$HOME/.local/bin:$PATH"
	if bw="$(bw_bin)" && "$bw" send receive --help >/dev/null 2>&1; then
		return 0
	fi

	echo "Installing the Bitwarden CLI into $HOME/.local/bin" >/dev/tty
	python3 - << 'PY' || return 1
import hashlib, json, os, stat, urllib.request, zipfile
from pathlib import Path

home = Path.home()
dest_dir = home / ".local" / "bin"
dest_dir.mkdir(parents=True, exist_ok=True)
os.chmod(dest_dir, 0o700)
cache = home / ".cache" / "bw-install"
cache.mkdir(parents=True, exist_ok=True)
os.chmod(cache, 0o700)

api = "https://api.github.com/repos/bitwarden/clients/releases?per_page=40"
req = urllib.request.Request(
    api,
    headers={"Accept": "application/vnd.github+json", "User-Agent": "bwsecrets"},
)
with urllib.request.urlopen(req, timeout=60) as resp:
    releases = json.load(resp)

asset = None
for rel in releases:
    if not str(rel.get("tag_name", "")).startswith("cli-v"):
        continue
    for item in rel.get("assets", []):
        name = item["name"]
        if (
            name.startswith("bw-linux-")
            and name.endswith(".zip")
            and "arm" not in name
            and "oss" not in name
        ):
            asset = item
            break
    if asset:
        break
if asset is None:
    raise SystemExit("Could not find a Bitwarden Linux CLI release")

digest = asset.get("digest", "")
archive = cache / asset["name"]
dl = urllib.request.Request(
    asset["browser_download_url"],
    headers={"User-Agent": "bwsecrets"},
)
with urllib.request.urlopen(dl, timeout=180) as resp, archive.open("wb") as out:
    while True:
        chunk = resp.read(1024 * 1024)
        if not chunk:
            break
        out.write(chunk)
sha = hashlib.sha256(archive.read_bytes()).hexdigest()
if digest and not digest.endswith(sha):
    archive.unlink(missing_ok=True)
    raise SystemExit("Bitwarden CLI checksum did not match the GitHub release")

extract = cache / "unz"
extract.mkdir(exist_ok=True)
with zipfile.ZipFile(archive) as zf:
    zf.extractall(extract)
binary = extract / "bw"
target = dest_dir / "bw"
target.write_bytes(binary.read_bytes())
os.chmod(target, 0o755)
PY
	export PATH="$HOME/.local/bin:$PATH"
	bw_bin >/dev/null
}

#** bw_status: print unauthenticated, locked, or unlocked
#*
bw_status() {
	local bw

	bw="$(bw_bin)" || {
		printf '%s\n' "unauthenticated"
		return 0
	}
	"$bw" status 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("unauthenticated")
    raise SystemExit(0)
print(data.get("status") or "unauthenticated")
'
}

#** bw_tty: fail when Bitwarden cannot prompt
#*
bw_tty() {
	if [[ -r /dev/tty && -w /dev/tty ]]; then
		return 0
	fi
	echo "Run this from a terminal so Bitwarden can prompt." >&2
	return 1
}

#** bw_login: log in without leaving the session key on the screen
#*
bw_login() {
	local bw answer

	bw_tty || return 1
	bw="$(bw_bin)" || return 1
	echo "Log in to Bitwarden. The session key stays in this process." >/dev/tty
	read -r -p "Use single sign-on? [y/N] " answer </dev/tty
	if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
		BW_SESSION="$("$bw" login --sso --raw </dev/tty)" || return 1
	else
		BW_SESSION="$("$bw" login --raw </dev/tty)" || return 1
	fi
	export BW_SESSION
	BW_UNLOCKED_HERE=yes
}

#** bw_unlock: prompt for the master password and export BW_SESSION
#*
# An existing BW_SESSION is reused. Otherwise bw prompts on the terminal.
# The session key is captured and is not written to the screen or a file.
#*
bw_unlock() {
	local bw status

	set +x
	bw_require || return 1
	bw="$(bw_bin)" || return 1

	if [[ -n "${BW_SESSION:-}" ]]; then
		status="$(bw_status)"
		if [[ "$status" == "unlocked" ]]; then
			return 0
		fi
	fi

	status="$(bw_status)"
	if [[ "$status" == "unauthenticated" ]]; then
		bw_login || return 1
		return 0
	fi

	bw_tty || return 1
	echo "Unlock Bitwarden. The master password is not stored or logged." >/dev/tty
	BW_SESSION="$("$bw" unlock --raw </dev/tty)" || return 1
	export BW_SESSION
	BW_UNLOCKED_HERE=yes
}

#** bw_lock: lock the vault when this process unlocked it
#*
bw_lock() {
	local bw

	set +x
	if [[ "${BW_UNLOCKED_HERE:-no}" != "yes" ]]; then
		unset BW_SESSION
		return 0
	fi
	if bw="$(bw_bin)"; then
		"$bw" lock >/dev/null 2>&1 || true
	fi
	unset BW_SESSION
	BW_UNLOCKED_HERE=no
}

#** bw_get_password: print one vault password to stdout
#*
# Arguments
#   $1 - item name
#
# Callers must capture stdout. This is the only function that writes a
# secret to stdout, and it writes nothing else.
#*
bw_get_password() {
	local name="$1"
	local bw

	set +x
	[[ -n "$name" ]] || return 1
	bw_unlock || return 1
	bw="$(bw_bin)" || return 1
	"$bw" get password "$name"
}

#** bw_item_id: print the id of an item with this exact name
#*
bw_item_id() {
	local name="$1"
	local bw

	set +x
	bw_unlock || return 1
	bw="$(bw_bin)" || return 1
	"$bw" list items --search "$name" | BW_ITEM_NAME="$name" python3 -c '
import json, os, sys
name = os.environ["BW_ITEM_NAME"]
try:
    items = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
for item in items:
    if item.get("name") == name and item.get("id"):
        print(item["id"])
        break
'
	unset BW_ITEM_NAME
}

#** bw_upsert_login: create or update a login item
#*
# Arguments
#   $1 - item name
#   $2 - username
#   $3 - secret
#   $4 - notes
#   $5 - uri
#
# The Bitwarden CLI prints a created item, including its password, on
# success. That output is discarded.
#*
bw_upsert_login() {
	local name="$1"
	local user="$2"
	local secret="$3"
	local notes="$4"
	local uri="$5"
	local bw id rc

	set +x
	[[ -n "$name" && -n "$secret" ]] || return 1
	bw_unlock || return 1
	bw="$(bw_bin)" || return 1
	# Sync before looking up the name so a new host does not create a
	# second copy of an item that is already in the account.
	"$bw" sync >/dev/null || return 1
	id="$(bw_item_id "$name")"
	rc=0

	if [[ -n "$id" ]]; then
		"$bw" get item "$id" \
			| BW_ITEM_SECRET="$secret" python3 -c '
import json, os, sys
item = json.load(sys.stdin)
login = item.get("login") or {}
login["password"] = os.environ["BW_ITEM_SECRET"]
item["login"] = login
item["reprompt"] = 1
json.dump(item, sys.stdout)
' \
			| "$bw" encode \
			| "$bw" edit item "$id" >/dev/null || rc=1
	else
		"$bw" get template item \
			| BW_ITEM_NAME="$name" \
			  BW_ITEM_USER="$user" \
			  BW_ITEM_SECRET="$secret" \
			  BW_ITEM_NOTES="$notes" \
			  BW_ITEM_URI="$uri" \
			  python3 -c '
import json, os, sys
item = json.load(sys.stdin)
item["type"] = 1
item["name"] = os.environ["BW_ITEM_NAME"]
item["notes"] = os.environ["BW_ITEM_NOTES"]
item["favorite"] = False
item["reprompt"] = 1
uri = os.environ.get("BW_ITEM_URI") or ""
item["login"] = {
    "username": os.environ["BW_ITEM_USER"],
    "password": os.environ["BW_ITEM_SECRET"],
    "totp": None,
    "uris": [{"uri": uri}] if uri else [],
}
json.dump(item, sys.stdout)
' \
			| "$bw" encode \
			| "$bw" create item >/dev/null || rc=1
	fi
	unset BW_ITEM_SECRET BW_ITEM_NAME BW_ITEM_USER BW_ITEM_NOTES BW_ITEM_URI
	[[ "$rc" -eq 0 ]] || return 1
	"$bw" sync >/dev/null || return 1
}

#** bw_password_matches: return 0 when the vault item matches a file
#*
# Arguments
#   $1 - item name
#   $2 - file whose entire contents are the expected secret
#*
bw_password_matches() {
	local name="$1"
	local file="$2"
	local bw

	set +x
	bw="$(bw_bin)" || return 1
	"$bw" get password "$name" | python3 -c '
import sys
from pathlib import Path
got = sys.stdin.read().strip()
expected = Path(sys.argv[1]).read_text(encoding="utf-8").strip()
raise SystemExit(0 if got == expected and got != "" else 1)
' "$file"
}

#** bw_prompt_secret: read a secret from the terminal into a variable
#*
# Arguments
#   $1 - variable name
#   $2 - prompt
#*
bw_prompt_secret() {
	local __var="$1"
	local prompt="$2"
	local value

	set +x
	bw_tty || return 1
	read -rs -p "$prompt" value </dev/tty || return 1
	printf '\n' >/dev/tty
	printf -v "$__var" '%s' "$value"
	unset value
}

#** bw_send_create: create a hidden, password-protected text Send
#*
# The text and password are read from the environment by python so they
# are not arguments of bw. stdout is the Send id and URL separated by a
# space. Both are secrets. Callers must not log them.
#
# Environment
#   BW_SEND_TEXT - Send body
#   BW_SEND_NAME - Send name
#*
bw_send_create() {
	local bw password password_again req url id

	set +x
	bw_unlock || return 1
	bw="$(bw_bin)" || return 1
	[[ -n "${BW_SEND_TEXT:-}" ]] || return 1
	export BW_SEND_TEXT BW_SEND_NAME
	bw_prompt_secret password "Bitwarden Send password: " || return 1
	bw_prompt_secret password_again "Repeat Send password: " || return 1
	if [[ "$password" != "$password_again" || -z "$password" ]]; then
		unset password password_again
		echo "Send passwords did not match." >&2
		return 1
	fi
	unset password_again

	req="$(
		BW_SEND_PASSWORD="$password" python3 - << 'PY'
import json, os
from datetime import datetime, timedelta, timezone
when = datetime.now(timezone.utc) + timedelta(hours=2)
body = {
    "object": "send",
    "name": os.environ.get("BW_SEND_NAME") or "bin-tokens",
    "notes": "Short-lived token copy for host provisioning.",
    "type": 0,
    "text": {"text": os.environ["BW_SEND_TEXT"], "hidden": True},
    "file": None,
    "maxAccessCount": 3,
    "deletionDate": when.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
    "expirationDate": None,
    "password": os.environ["BW_SEND_PASSWORD"],
    "emails": None,
    "disabled": False,
    "hideEmail": True,
}
print(json.dumps(body))
PY
	)" || {
		unset password BW_SEND_PASSWORD
		return 1
	}
	unset password BW_SEND_PASSWORD BW_SEND_TEXT

	url="$(printf '%s' "$req" | "$bw" encode | "$bw" send create)" || {
		unset req url
		echo "Could not create the Bitwarden Send." >&2
		return 1
	}
	unset req
	id="$(printf '%s' "$url" | python3 -c '
import re, sys
text = sys.stdin.read()
match = re.search(r"(https://\S*/send/([^/\s]+)/\S+)", text)
if not match:
    raise SystemExit(1)
print(match.group(2))
print(match.group(1))
')" || {
		unset url id
		echo "Bitwarden did not return a Send URL." >&2
		return 1
	}
	printf '%s\n' "$id"
	unset url id
}

#** bw_send_receive: read a Send and print its text
#*
# Arguments
#   $1 - Send URL
#
# bw prompts for the Send password on the terminal.
#*
bw_send_receive() {
	local url="$1"
	local bw

	set +x
	[[ -n "$url" ]] || return 1
	bw_tty || return 1
	bw_require || return 1
	bw="$(bw_bin)" || return 1
	echo "Enter the Bitwarden Send password. It is not stored." >/dev/tty
	"$bw" send receive "$url" </dev/tty
}

#** bw_send_delete: delete a Send by id
#*
bw_send_delete() {
	local id="$1"
	local bw

	set +x
	[[ -n "$id" ]] || return 1
	bw_unlock || return 1
	bw="$(bw_bin)" || return 1
	"$bw" send delete "$id" >/dev/null
}

#** bw_pending_send_path: file that holds a Send URL on a new host
#*
bw_pending_send_path() {
	printf '%s\n' "$HOME/.config/bitwarden/pending-send"
}

#** curl_with_token: call curl with an auth header that is not in argv
#*
# Arguments
#   $1 - header name
#   $2 - header value
#   remaining arguments are passed to curl
#*
curl_with_token() {
	local header_name="$1"
	local header_value="$2"
	local cfg rc

	set +x
	shift 2
	cfg="$(secret_tmp)" || return 1
	if ! BW_H_FILE="$cfg" BW_H_NAME="$header_name" BW_H_VALUE="$header_value" \
		python3 - << 'PY'
import os
from pathlib import Path
value = os.environ["BW_H_VALUE"]
if any(ch in value for ch in '"\r\n'):
    raise SystemExit(1)
Path(os.environ["BW_H_FILE"]).write_text(
    'header = "%s: %s"\n' % (os.environ["BW_H_NAME"], value),
    encoding="utf-8",
)
PY
	then
		unset BW_H_FILE BW_H_NAME BW_H_VALUE
		secret_shred "$cfg"
		return 1
	fi
	unset BW_H_FILE BW_H_NAME BW_H_VALUE
	rc=0
	curl --config "$cfg" "$@" || rc=$?
	secret_shred "$cfg"
	return "$rc"
}

#** git_clone_auth: clone without writing the token into .git/config
#*
# Arguments
#   $1 - https URL
#   $2 - destination directory
#   $3 - token
#*
git_clone_auth() {
	local url="$1"
	local dest="$2"
	local token="$3"

	set +x
	if [[ -z "$token" ]]; then
		git clone "$url" "$dest"
		return
	fi
	# The helper expands GITHUB_TOKEN in the child environment. The token
	# is not part of the git command line and -c does not update .git/config.
	GITHUB_TOKEN="$token" \
	GIT_TERMINAL_PROMPT=0 \
	git -c credential.helper= \
		-c 'credential.helper=!f() { echo username=x-access-token; echo "password=$GITHUB_TOKEN"; }; f' \
		clone "$url" "$dest"
}

#** load_vault_tokens: set github_token, gitlab_token, gitlab_cee_token
#*
# github_token is required. The GitLab tokens are optional.
#*
load_vault_tokens() {
	set +x
	bw_unlock || return 1
	if ! github_token="$(bw_get_password "$BW_ITEM_GITHUB")"; then
		echo "Bitwarden has no item named $BW_ITEM_GITHUB." >&2
		echo "On the machine that still has the plaintext token, run bw-import-tokens." >&2
		return 1
	fi
	github_token="${github_token//$'\n'/}"
	if [[ -z "$github_token" || "$github_token" == *" "* ]]; then
		echo "Bitwarden item $BW_ITEM_GITHUB is empty." >&2
		github_token=""
		return 1
	fi
	if gitlab_token="$(bw_get_password "$BW_ITEM_GITLAB" 2>/dev/null)"; then
		gitlab_token="${gitlab_token//$'\n'/}"
	else
		gitlab_token=""
	fi
	if [[ "$gitlab_token" == *" "* ]]; then
		gitlab_token=""
	fi
	if gitlab_cee_token="$(bw_get_password "$BW_ITEM_GITLAB_CEE" 2>/dev/null)"; then
		gitlab_cee_token="${gitlab_cee_token//$'\n'/}"
	else
		gitlab_cee_token=""
	fi
	if [[ "$gitlab_cee_token" == *" "* ]]; then
		gitlab_cee_token=""
	fi
}

#** ssh_key_generate: create an SSH key and reject an empty passphrase
#*
# Arguments
#   $1 - private key path
#   $2 - rsa or ed25519 (default ed25519)
#*
ssh_key_generate() {
	local priv="$1"
	local kind="${2:-ed25519}"

	mkdir -p "$(dirname "$priv")"
	chmod 700 "$(dirname "$priv")"
	echo "Choose a passphrase for the new SSH key." >/dev/tty
	echo "An empty passphrase is rejected and the key is removed." >/dev/tty
	if [[ "$kind" == "rsa" ]]; then
		ssh-keygen -t rsa -b 4096 -f "$priv" </dev/tty || return 1
	else
		ssh-keygen -t ed25519 -f "$priv" </dev/tty || return 1
	fi
	if ssh-keygen -P "" -y -f "$priv" >/dev/null 2>&1; then
		rm -f "$priv" "${priv}.pub"
		echo "The SSH key had an empty passphrase, so it was removed." >&2
		return 1
	fi
	chmod 600 "$priv"
	chmod 644 "${priv}.pub"
}

#** strip_lab_token: write lab.toml without a token line
#*
# Arguments
#   $1 - source lab.toml
#   $2 - destination file
#*
strip_lab_token() {
	local src="$1"
	local dest="$2"

	python3 -c '
import re, sys
from pathlib import Path
src, dest = sys.argv[1:]
lines = Path(src).read_text(encoding="utf-8").splitlines(True)
kept = [line for line in lines if not re.match(r"\s*token\s*=", line)]
Path(dest).write_text("".join(kept), encoding="utf-8")
' "$src" "$dest"
	chmod 600 "$dest"
}
