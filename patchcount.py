#!/usr/bin/env python
#
# First create a config file in either /etc or ~/
# Contents should be as follows
#
# -------------------------------------------------
# [global]
# default = https://gitlab.com
# ssl_verify = true
# timeout = 5
# 
# [gitlab]
# url = https://gitlab.com
# private_token = <your private gitlab token here>
# api_version = 4
# -------------------------------------------------
#
# Then you must set an environment variable..
# 
#   PYTHON_GITLAB_CFG=~/.python-gitlab.cfg
# 
# ..or..
#
#   PYTHON_GITLAB_CFG=/etc/python-gitlab.cfg
#
# .. depending on where you created the config file.
#

import gitlab

# kernel-test
project_id="24118165"
mr_id="859"

gl = gitlab.Gitlab.from_config('gitlab')
gl_project = gl.projects.get(project_id)
mr = gl_project.mergerequests.get(mr_id)
ncommits = len(mr.commits())

print(f'Working on {gl_project.name} MR {mr_id}')
print(f"MR author: {mr.author['name']}")
print(f'Number of commits: {ncommits}')
