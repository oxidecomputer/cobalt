# This is python port of https://github.com/passsy/git-revision/
# with some modifications to our preferences and use-cases.
# See LICENSE.git_revision.md in the root of the repository.
# -------------------------------------------------------------
#
#   Copyright 2021 Oxide Computer Company
#   Copyright 2018 Pascal Welsch
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

import argparse
import datetime
import pathlib
import re
import subprocess

from functools import cached_property, cache
from typing import List, Iterator, Optional, Union, Tuple


parser = argparse.ArgumentParser(
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
)
parser.add_argument(
    "-c",
    "--context",
    dest="context",
    default=None,
    help=(
        "Use this path instead of cwd"
    ),
)
parser.add_argument(
    "-b",
    "--baseBranch",
    dest="base_branch",
    default="main",
    help=(
        "The base branch where most of the development happens. Often what is"
        " set as baseBranch in github. Only on the baseBranch the revision can"
        " become only digits."
    ),
)
parser.add_argument(
    "-y",
    "--yearFactor",
    dest="year_factor",
    type=int,
    default=1000,
    help="Revision increment count per year.",
)
parser.add_argument(
    "-d",
    "--maxGapDuration",
    dest="stop_debounce",
    type=int,
    default=48,
    help=(
        "Time between two commits which are further apart than this"
        " stopDebounce (in hours) will not be included into the timeComponent."
        " A project on hold for a few months will therefore not increase the"
        " revision drastically when development starts again."
    ),
)
parser.add_argument(
    "-n",
    "--name",
    default="",
    help=(
        "A human-readable name and identifier of a revision"
        " ('73_<name>+21_995321c'). Can be anything which gives the revision"
        " more meaning i.e. the number of the PullRequest when building on CI."
        " Allowed characters: [a-zA-Z0-9_-/] any letter, digits, underscore,"
        " dash and slash. Invalid characters will be removed."
    ),
)
parser.add_argument(
    "--full",
    action="store_true",
    default=False,
    help=(
        "Shows full information about the current revision and extracted"
        " information"
    ),
)
parser.add_argument(
    "revision",
    nargs="?",
    default="HEAD",
    help="Optional git revision string (sha) or HEAD etc",
)
options = parser.parse_args()


def list_to_tuple(function):
    """Decorator function to turn a list into a tuple"""

    def wrapper(*args):
        args = [tuple(x) if type(x) == list else x for x in args]
        result = function(*args)
        result = tuple(result) if type(result) == list else result
        return result

    return wrapper


def parse_rev_list(rev_text):
    """Parse a string that looks like this into a shaw and a time:
    commit ceeaf2bc13b968c34f29159404604a7be3bf7d6f
    1633124754
    """
    parts = rev_text.split("\n")
    return Commit(parts[0].replace("commit", "").strip(), int(parts[1].strip()))


class Commit:
    """Simple representation of a commit as parsed from git output"""

    def __init__(self, sha: str, raw_date: int):
        if "commit" in sha:
            raise Exception
        self.sha = sha
        self.raw_date = raw_date

    def __str__(self):
        return f"Commit(sha1: {self.sha[0:7]},date: {self.raw_date})"

    @property
    def date(self):
        """Turn the raw time stap (seconds since the epoc) into a datetime"""
        return datetime.datetime.fromtimestamp(self.raw_date)


class LocalChanges:
    """Represent local changes in a queryable way"""

    def __init__(self, files_changed, additions, deletions):
        self.files_changed = int(files_changed)
        self.additions = int(additions)
        self.deletions = int(deletions)

    def __str__(self):
        return f"{self.files_changed} +{self.additions} -{self.deletions}"

    @property
    def short_stats(self) -> str:
        if self.files_changed + self.additions + self.deletions == 0:
            return "no changes"
        else:
            return (
                f"files changed: {self.files_changed}, additions(+):"
                f" {self.additions}, deletions(-): {self.deletions}"
            )


class GitClient:
    def __init__(self, working_dir):
        self.working_dir = working_dir

    def rev_list(
        self, revision: Union[str, int], first_parent_only: bool = False
    ) -> List[Commit]:
        # git rev-list --pretty=%ct%n [--first-parent] <revision>
        args = ["rev-list", "--pretty=%ct%n"]
        if first_parent_only:
            args.append("--first-parent")
        args.append(revision)

        result = self._git(args)

        if not result.stdout:
            return []
        # Command returns a string like this:
        # λ git rev-list --pretty=%ct%n HEAD
        # commit ceeaf2bc13b968c34f29159404604a7be3bf7d6f
        # 1633124754
        #
        # commit b7af84ff00a946faf3bf17d9f1ea663b7c6fb4b2
        # 1632354944
        # we need  a list of commits that have sha and time
        # split at \n\n to get commits,
        commit_list = filter(
            None, (line.rstrip() for line in result.stdout.split("\n\n"))
        )
        return list(map(parse_rev_list, commit_list))

    def sha1(self, revision: int) -> str:
        """Returns a full sha1 hash as a string or an empty string"""
        args = ["rev-parse", revision]

        result = self._git(args)

        # TODO: check for multi-line hash?
        return result.stdout.strip()

    def head_branch_name(self) -> str:
        args = ["symbolic-ref", "--short", "-q", "HEAD"]
        result = self._git(args)
        return result.stdout.strip()

    def local_changes(self, revision: int) -> LocalChanges:
        args = ["diff", "--shortstat", "HEAD"]
        if revision != "HEAD":
            return LocalChanges(0, 0, 0)
        result = self._git(args)
        return self._parse_diff_short_stat(result.stdout)

    def branch_local_or_remote(self, branch_name: str) -> Iterator[str]:
        args = ["branch", "--all", "--list", f"*{branch_name}"]
        result = self._git(args)

        branches = result.stdout.split("\n")
        for branch in branches:
            new_branch = branch.replace("* ", "")
            yield new_branch.strip()

    def _parse_diff_short_stat(self, text: str) -> LocalChanges:
        if not text:
            return LocalChanges(0, 0, 0)
        parts = map(lambda x: x.strip(), text.split(","))
        files_changed = 0
        additions = 0
        deletions = 0

        for part in parts:
            if "changed" in part:
                files_changed = self._starting_number(part)
            if "(+)" in part:
                additions = self._starting_number(part)
            if "(-)" in part:
                deletions = self._starting_number(part)
        return LocalChanges(files_changed, additions, deletions)

    @staticmethod
    def _starting_number(text: str) -> Optional[int]:
        matches = re.findall(r"\d+", text)
        return None if not matches else matches[0]

    # functools cache can't take a list since it isn't hashable and immutable.
    # To get around this without changing everything everywhere we use
    # this decorator to turn the list into a tuple which is immutable and hashable
    # and then turn it back into a list as we want to mutate it and pass it to the
    # subprocess
    # We do this before using functools cache decorator
    @list_to_tuple
    @cache
    def _git(
        self, args: Union[List[str], Tuple[str]]
    ) -> subprocess.CompletedProcess:
        args = ["git"] + list(args)
        result = subprocess.run(
            args, capture_output=True, cwd=self.working_dir, text=True
        )
        return result


class GitVersionerConfig:
    def __init__(
        self, base_branch, repo_path, year_factor, stop_debounce, name, rev
    ):
        self.base_branch = base_branch.strip()
        self.repo_path = repo_path
        self.year_factor = year_factor
        self.stop_debounce = stop_debounce
        self.name = name.strip()
        self.rev = rev.strip()


class GitVersioner:
    def __init__(self, config: GitVersionerConfig):
        self.DEFAULT_BRANCH = "main"
        self.DEFAULT_YEAR_FACTOR = 1000
        self.DEFAULT_STOP_DEBOUNCE = 48

        self.config = config
        self.git_client = GitClient(config.repo_path)

    @classmethod
    def from_config(cls, config: GitVersionerConfig):
        return cls(config)

    @cached_property
    def revision(self) -> int:
        commits = self.base_branch_commits
        time_component = self.base_branch_time_component
        return len(commits) + time_component

    @property
    def name(self) -> str:
        name = ""
        if self.config.name and (self.config.name != self.config.base_branch):
            name = f"_{self.config.name}"
        if self.config.rev == "HEAD":
            branch = self.head_branch_name
            if (branch is not None) and (branch != self.config.base_branch):
                name = f"_{branch}"
        else:
            if (
                not self.config.rev.startswith(self.sha_short)
                and self.config.rev != self.config.base_branch
            ):
                name = f"_{self.config.rev}"
            if self.config.name and self.config.name != self.config.base_branch:
                name = f"_{self.config.name}"
        return name

    @property
    def version_name(self) -> str:
        rev = self.revision
        hash_ = self.sha_short
        additional_commits = self.feature_branch_commits
        name = self.name
        dirty_part = ""
        further_part = (
            f"+{len(additional_commits)}" if additional_commits else ""
        )

        if self.config.rev == "HEAD":
            changes = (
                "files changed"
                in self.git_client.local_changes(self.config.rev).short_stats
            )
            dirty_part = f"-dirty" if changes else ""

        return f"{rev}{name}{further_part}_{hash_}{dirty_part}"

    @property
    def all_first_base_branch_commits(self) -> List[Commit]:
        base = list(
            self.git_client.branch_local_or_remote(self.config.base_branch)
        )[0]
        commits = self.git_client.rev_list(base, first_parent_only=True)
        return commits

    @property
    def head_branch_name(self) -> str:
        return self.git_client.head_branch_name()

    @property
    def sha1(self) -> str:
        return self.git_client.sha1(self.config.rev)

    @property
    def sha_short(self) -> str:
        return self.sha1[0:7]

    @property
    def local_changes(self) -> LocalChanges:
        return self.git_client.local_changes(self.config.rev)

    def commits(self) -> List[Commit]:
        return self.git_client.rev_list(self.config.rev)

    @property
    def feature_branch_origin(self) -> Optional[Commit]:
        first_base_commits = self.all_first_base_branch_commits
        all_head_commits = self.commits()

        first_base_sha_list = [x.sha for x in first_base_commits]
        for commit in all_head_commits:
            if commit.sha in first_base_sha_list:
                return commit
        return None

    @property
    def base_branch_commits(self) -> List[Commit]:
        origin = self.feature_branch_origin
        if origin is None:
            return []
        else:
            return self.git_client.rev_list(origin.sha)

    @property
    def feature_branch_commits(self) -> List[Commit]:
        origin = self.feature_branch_origin
        if origin is not None:
            return self.git_client.rev_list(f"{self.config.rev}...{origin.sha}")
        else:
            return self.commits()

    @property
    def base_branch_time_component(self) -> int:
        commits = self.base_branch_commits
        return self._time_component(commits)

    @property
    def feature_branch_time_component(self) -> int:
        commits = self.feature_branch_commits
        return self._time_component(commits)

    def _time_component(self, commits: List[Commit]) -> int:
        if not commits:
            return 0
        complete_time = commits[0].date - commits[-1].date
        if complete_time == datetime.timedelta(seconds=0):
            return 0

        # accumulate large gaps as a time delta?
        gaps = datetime.timedelta(seconds=0)
        for idx, commit in enumerate(commits[1:-1], start=1):
            # rev-list comes in reversed order
            next_commit = commits[idx - 1]
            diff = next_commit.date - commit.date
            diff_hours = diff.total_seconds() // 3600
            if diff_hours >= self.config.stop_debounce:
                gaps += diff
        # remove large gaps
        working_time = complete_time - gaps
        return self._year_factor(working_time)

    def _year_factor(self, duration: datetime.timedelta) -> int:
        one_year = datetime.timedelta(days=365)
        return round(
            (duration.total_seconds() * self.config.year_factor)
            / one_year.total_seconds()
            + 0.5
        )


def main():
    repo_path = pathlib.Path.cwd() if options.context is None else options.context
    config = GitVersionerConfig(
        options.base_branch,
        repo_path=repo_path,
        year_factor=options.year_factor,
        stop_debounce=options.stop_debounce,
        name=options.name,
        rev=options.revision,
    )
    version = GitVersioner.from_config(config)
    if options.full:
        full_print(version)
    else:
        print(version.version_name)


def full_print(version):
    print(f"versionCode: {version.revision}")
    print(f"versionName: {version.version_name}")
    print(f"baseBranch: {version.config.base_branch}")
    print(f"currentBranch: {version.head_branch_name}")
    print(f"sha1: {version.sha1}")
    print(f"shaShort: {version.sha_short}")
    print(
        "completeFirstOnlyBaseBranchCommitCount:"
        f" {len(version.all_first_base_branch_commits)}"
    )
    print(f"baseBranchCommitCount: {len(version.base_branch_commits)}")
    print(f"baseBranchTimeComponent: {version.base_branch_time_component}")
    print(f"featureBranchCommitCount: {len(version.feature_branch_commits)}")
    print(
        f"featureBranchTimeComponent: {version.feature_branch_time_component}"
    )
    print(f"featureOrigin: {version.feature_branch_origin.sha}")
    print(f"yearFactor: {version.config.year_factor}")
    print(f"localChanges: {version.local_changes}")
    print(f"working_dir: {version.config.repo_path}")


if __name__ == "__main__":
    main()
