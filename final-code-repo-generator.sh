#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

if [[ "${BASH_TRACE:-0}" == "1" ]]; then
    set -o xtrace
fi

cd "$(dirname "$0")"

REPOSITORY_URL=""
BRANCH_DEVELOP=""
BRANCH_RELEASE=""
REPOSITORY_PATH=""
SOURCECODE_PATH=""

function process_arguments()
{
    if [[ "$#" != 3 ]]
    then
        echo "Usage:"
        echo " $0 <github-repository-url> <dev-branch> <release-branch>"
        echo "Example:"
        echo " $0 git@github.com:btu-mit-08-2023/final-code.git develop release"
        exit 1
    fi

    REPOSITORY_URL=$1
    BRANCH_DEVELOP=$2
    BRANCH_RELEASE=$3
}

function create_directories()
{
    REPOSITORY_PATH=$(mktemp --directory)
    pushd ./code >> /dev/null
    SOURCECODE_PATH=$(realpath .)
    popd >> /dev/null
}

function delete_directories()
{
    rm -rf $REPOSITORY_PATH || true
}

function wait_for_enter()
{
    echo
    read -p "Press <Enter> to continue with '$1'"
    echo
}

function initialize_state()
{
    git clone $REPOSITORY_URL $REPOSITORY_PATH
    cd $REPOSITORY_PATH

    git push --delete origin $BRANCH_DEVELOP || true
    git push --delete origin $BRANCH_RELEASE || true
    git branch --all | grep -o -P '(?<=remotes/origin/)(TEMP-[A-Z]-\d+)' | xargs -n 1 git push --delete origin || true
    git checkout --orphan main || true
    echo "main branch" > README.txt
    git add .
    git commit -m "Create main branch." || true
    git push --set-upstream origin main || true
    git checkout --orphan $BRANCH_RELEASE
    echo "$BRANCH_RELEASE branch" > README.txt
    git add .
    git commit -m "Create $BRANCH_RELEASE branch."
    git push --set-upstream origin $BRANCH_RELEASE
    git switch -C $BRANCH_DEVELOP
    echo "$BRANCH_DEVELOP branch" > README.txt
    git add .
    git commit -m "Create $BRANCH_DEVELOP branch."
    git push --set-upstream origin $BRANCH_DEVELOP
}

# $1 - case
function update_files()
{
    echo "# $RANDOM$(date +%s)$RANDOM" > lib.py
    cat "$SOURCECODE_PATH/lib/$1.py" >> lib.py
    echo "# $RANDOM$(date +%s)$RANDOM" > test_lib.py
    cat "$SOURCECODE_PATH/test_lib/$1.py" >> test_lib.py
}

# $1 - message
# $2 - author_name
# $3 - author_email
function commit_files()
{
    git add --no-ignore-removal .
    GIT_COMMITTER_NAME="$2" GIT_COMMITTER_EMAIL="$3" git commit --message="$1" --author="$2 <$3>" || true
}

# $1 - case
# $2 - author name 1
# $3 - author email 1
# $4 - author name 2
# $5 - author email 2
function update_state_mergeable()
{
    wait_for_enter $1

    TEMP_BRANCH_NAME1="TEMP-A-$RANDOM$(date +%s)"
    TEMP_BRANCH_NAME2="TEMP-B-$RANDOM$(date +%s)"
    TEMP_BRANCH_NAME3="TEMP-C-$RANDOM$(date +%s)"
    git switch $BRANCH_DEVELOP
    git switch -C $TEMP_BRANCH_NAME1
    update_files pytest_passed_black_passed
    commit_files pytest_passed_black_passed "$2" "$3"
    update_files pytest_passed_black_passed
    commit_files pytest_passed_black_passed "$4" "$5"
    git push --set-upstream origin $TEMP_BRANCH_NAME1
    git switch $BRANCH_DEVELOP
    git switch -C $TEMP_BRANCH_NAME2
    update_files pytest_passed_black_passed
    commit_files pytest_passed_black_passed "$2" "$3"
    update_files pytest_passed_black_passed
    commit_files pytest_passed_black_passed "$4" "$5"
    git push --set-upstream origin $TEMP_BRANCH_NAME2
    git switch $BRANCH_DEVELOP
    git switch -C $TEMP_BRANCH_NAME3
    update_files pytest_passed_black_passed
    commit_files pytest_passed_black_passed "$2" "$3"
    update_files pytest_passed_black_passed
    commit_files pytest_passed_black_passed "$4" "$5"
    update_files "$1"
    commit_files "$1" "$2" "$3"
    update_files "$1"
    commit_files "$1" "$4" "$5"
    git push --set-upstream origin $TEMP_BRANCH_NAME3
    git switch $BRANCH_DEVELOP
    git merge --no-commit --strategy=ort --strategy-option=theirs $TEMP_BRANCH_NAME1
    commit_files "Merging $TEMP_BRANCH_NAME1" "$2" "$3"
    git merge --no-commit --strategy=ort --strategy-option=theirs $TEMP_BRANCH_NAME2
    commit_files "Merging $TEMP_BRANCH_NAME2" "$2" "$3"
    git merge --no-commit --strategy=ort --strategy-option=theirs $TEMP_BRANCH_NAME3
    commit_files "Merging $TEMP_BRANCH_NAME3, $1" "$2" "$3"
    git push
    # git switch $BRANCH_RELEASE
    # git merge  $BRANCH_DEVELOP
    # git push
}

# $1 - case
# $2 - author name 1
# $3 - author email 1
# $4 - author name 2
# $5 - author email 2
function update_state_unmergeable()
{
    wait_for_enter "unmergeable"

    git switch $BRANCH_DEVELOP
    update_files pytest_passed_black_passed
    commit_files pytest_passed_black_passed "$2" "$3"
    git switch $BRANCH_RELEASE
    update_files pytest_passed_black_passed
    commit_files pytest_passed_black_passed "$4" "$5"
    # git merge  $BRANCH_DEVELOP
}

trap delete_directories EXIT

process_arguments $@
create_directories
initialize_state

update_state_mergeable pytest_absent_black_failed 'Tian Zhang' 'tian.zhang@triflesoft.org' 'Ming Chen'  'ming.chen@triflesoft.org'
update_state_mergeable pytest_absent_black_failed 'Ming Chen'  'ming.chen@triflesoft.org'  'Tian Zhang' 'tian.zhang@triflesoft.org'
update_state_mergeable pytest_absent_black_passed 'Tian Zhang' 'tian.zhang@triflesoft.org' 'Ming Chen'  'ming.chen@triflesoft.org'
update_state_mergeable pytest_absent_black_passed 'Ming Chen'  'ming.chen@triflesoft.org'  'Tian Zhang' 'tian.zhang@triflesoft.org'
update_state_mergeable pytest_failed_black_failed 'Tian Zhang' 'tian.zhang@triflesoft.org' 'Ming Chen'  'ming.chen@triflesoft.org'
update_state_mergeable pytest_failed_black_failed 'Ming Chen'  'ming.chen@triflesoft.org'  'Tian Zhang' 'tian.zhang@triflesoft.org'
update_state_mergeable pytest_failed_black_passed 'Tian Zhang' 'tian.zhang@triflesoft.org' 'Ming Chen'  'ming.chen@triflesoft.org'
update_state_mergeable pytest_failed_black_passed 'Ming Chen'  'ming.chen@triflesoft.org'  'Tian Zhang' 'tian.zhang@triflesoft.org'
update_state_mergeable pytest_passed_black_failed 'Tian Zhang' 'tian.zhang@triflesoft.org' 'Ming Chen'  'ming.chen@triflesoft.org'
update_state_mergeable pytest_passed_black_failed 'Ming Chen'  'ming.chen@triflesoft.org'  'Tian Zhang' 'tian.zhang@triflesoft.org'
update_state_mergeable pytest_passed_black_passed 'Tian Zhang' 'tian.zhang@triflesoft.org' 'Ming Chen'  'ming.chen@triflesoft.org'
update_state_mergeable pytest_passed_black_passed 'Ming Chen'  'ming.chen@triflesoft.org'  'Tian Zhang' 'tian.zhang@triflesoft.org'
update_state_mergeable pytest_syntax_black_failed 'Tian Zhang' 'tian.zhang@triflesoft.org' 'Ming Chen'  'ming.chen@triflesoft.org'
update_state_mergeable pytest_syntax_black_failed 'Ming Chen'  'ming.chen@triflesoft.org'  'Tian Zhang' 'tian.zhang@triflesoft.org'

update_state_unmergeable pytest_passed_black_passed 'Ming Chen'  'ming.chen@triflesoft.org'  'Tian Zhang' 'tian.zhang@triflesoft.org'
