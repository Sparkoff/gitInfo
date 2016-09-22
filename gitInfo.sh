#!/bin/bash


## Main command
printGitTable() {
    if isGitRepository; then
        # Repo part
        drawSeparator;
        drawSeparator "Repository: "$(basename "$PWD");
        branchName;
        stash;
        remoteName;
        drawLine

        # Activity part
        drawSeparator;
        drawSeparator "Working";
        staging;
        changes;
        untracked;
        noWork;

        # Commit part
        if [[ $(git rev-parse --abbrev-ref HEAD) != "master" ]]; then
            drawSeparator;
            drawSeparator "Commits";
            commits;
            drawLine
        fi
        drawSeparator;
    else
        print 'This is not a git repository.';
        exit 1;
    fi;
}



## Drawing method
# Draw horizontals table line and Titles
drawSeparator() {
    # get termainal width
    width=$(tput cols);

    if [ $# -eq 1 ]; then
        # It will be a Title
        # draw left vertical line of table with style
        line="\033[35m|";

        # start styling title
        line+="\033[46m\033[37m";

        # compute white space to center title
        space=$(( width - 2 - ${#1} ));
        space=$(( space / 2 ));

        # draw left space
        for ((i=0; i<$((space)); i++)); do
            line+=" ";
        done

        # draw title
        line+="$1";

        # draw right space
        for ((i=0; i<$((width - 2 - $space - ${#1})); i++)); do
            line+=" ";
        done

        # draw right vertical line of table and clean style
        line+="\033[0m\033[35m|\033[0m";

        print "$line";
    else
        # It will be an horizontal line
        # draw left corner with style
        line="\033[35m+";

        # draw horizontal line
        for ((i=0; i<$((width - 2)); i++)); do
            line+="-";
        done

        # draw right corner and clean style
        line+="+\033[0m";

        print $line;
    fi;
}

# Draw table lines
drawLine() {
    # get termainal width
    width=$(tput cols);

    # draw left vertical line of table with style
    line="\033[35m|\033[0m ";

    # set max column length
    #   first will have branch name, type of changes or commit hash
    #   second (if any) will have file names or commint message
    #   third will have branch status, number of line changes or commit date
    firstColumnSize=18;
    thirdColumnSize=22;

    # lines without text will be empty lines
    # lines with only one info will be sub-titles
    # lines with two or more infos will be info lines
    if [ $# -eq 1 ]; then
        # set sub-titles style
        if [[ $1 == "Staging" ]]; then
            line+="\033[32m$1\033[0m";
        elif [[ $1 == "Changes" ]]; then
            line+="\033[31m$1\033[0m";
        elif [[ $1 == "Untracked" ]]; then
            line+="\033[31m$1\033[0m";
        else
            line+="$1";
        fi

        # draw white space
        for ((i=0; i<$((width - 3 - ${#1})); i++)); do
            line+=" ";
        done
    elif [ $# -ge 2 ]; then
        # handle small screen
        # TODO: review system
        if [ $((width - 3 - firstColumnSize - thirdColumnSize)) -lt 10 ]; then
            firstColumnSize=13;
            thirdColumnSize=10;
            if [ ${#1} -gt 13 ]; then
                firstColumnSize=16;
            fi
            if [ $# -eq 3 ]; then
                if [ ${#3} -gt $thirdColumnSize ]; then
                    if [ ${#3} -gt 15 ]; then
                        thirdColumnSize=18;
                    else
                        thirdColumnSize=15;
                    fi
                fi
            fi
        fi

        # draw first column and its white space
        line+="$1";
        for ((i=0; i<$((firstColumnSize - ${#1})); i++)); do
            line+=" ";
        done

        # print second column text
        line+="$2";

        # check if there is a third column to print
        # if not, only print white space to the end
        if [ $# -eq 3 ]; then
            # handle small screen
            # TODO: review system
            if [ ${#3} -gt $thirdColumnSize ]; then
                if [ ${#3} -gt 15 ]; then
                    thirdColumnSize=18;
                else
                    thirdColumnSize=15;
                fi
            fi

            # print second column white space
            for ((i=0; i<$((width - 3 - firstColumnSize - ${#2} - thirdColumnSize)); i++)); do
                line+=" ";
            done

            # stylish third column informations (remote branch and file infos)
            diff=$(statusDiff "$3");
            status=$(statusRemote "$3");

            # print third column text
            if [[ $diff != "" ]]; then
                line+="$diff";
            elif [[ $status != "" ]]; then
                line+="$status";
            else
                line+="$3";
            fi

            # print third column white space
            for ((i=0; i<$((thirdColumnSize - ${#3})); i++)); do
                line+=" ";
            done
        else
            # print white space to the end of the line
            for ((i=0; i<$((width - 3 - firstColumnSize - ${#2})); i++)); do
                line+=" ";
            done
        fi
    else
        # print empty line
        for ((i=0; i<$((width - 3)); i++)); do
            line+=" ";
        done
    fi;

    # draw right vertical line of table with style
    line+="\033[35m|\033[0m";

    print "$line";
}

# Number of ghanged lines in file
statusDiff() {
    diff="";

    # input will be "1+ 3-"
    # separate these elements
    diffPlus=$(echo $1 | grep -o "[0-9]\{1,\}+");
    diffMoins=$(echo $1 | grep -o "[0-9]\{1,\}-");

    # stylish elements
    if [[ $diffPlus != "" ]]; then
        diff+="\033[32m$diffPlus\033[0m";
    fi
    if [[ $diffMoins != "" ]]; then
        if [[ $diffPlus != "" ]]; then
            # print simple space between (1+ 3-)
            diff+=" ";
        fi
        diff+="\033[31m$diffMoins\033[0m";
    fi

    echo $diff
}

# Number of commits ahead/behind master
statusRemote() {
    status="";

    # input will be "1 ahead, 3 behinds"
    # separate these elements
    statusPlus=$(echo $1 | grep -o "[0-9]\{1,\} ahead[s]\{0,1\}");
    statusMoins=$(echo $1 | grep -o "[0-9]\{1,\} behind[s]\{0,1\}");

    # stylish elements
    if [[ $statusPlus != "" ]]; then
        status+="\033[32m$statusPlus\033[0m";
    fi
    if [[ $statusMoins != "" ]]; then
        if [[ $statusPlus != "" ]]; then
            # print periode between (1 ahead, 3 behinds)
            status+=", ";
        fi
        status+="\033[31m$statusMoins\033[0m";
    fi

    echo $status
}



## Git informations
# Current branch name
branchName() {
    # get current branch name
    branch=$(git rev-parse --abbrev-ref HEAD);

    # call tag getter method
    tag=$(tag);

    # if there is a tag, prepare text
    # TODO: if there is no tag, print stashed files instead
    if [[ $tag != "" ]]; then
        tag="Tag: "$tag;
    fi

    # draw method call
    drawLine "Current branch:" $branch "$tag";
}

# Current commit tag
tag() {
    # get current commit hash
    currentHash=$(git rev-parse HEAD 2> /dev/null);

    # get current commit tag
    tag=$(git describe --exact-match --tags $currentHash 2> /dev/null);

    # if no tag, echoing empty string
    if [[ -n ${tag} ]]; then
        echo $tag;
    else
        echo "";
    fi
}

# Number of stashed files
stash() {
    # get current branch name
    branch=$(git rev-parse --abbrev-ref HEAD);

    # get current branch number of stashed files
    stashes=$(git stash list | grep "on $branch" | wc -l);
    stashes=$(trim "$stashes");

    # draw method call
    # if no stashed files, do not draw anything
    if [ $stashes -gt 0 ]; then
        # print stashed files in third column, as branch informations
        drawLine "" "$stashes stashed";
    fi
}

# Cuurent branch remote name
remoteName() {
    # get remote branch name
    remote=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null);

    # if no remote branch, do not render anything
    if [[ -n "${remote}" && "${remote}" != "@{upstream}" ]]; then
        # remote status method call
        status=$(remoteStatus);

        # draw method call
        drawLine "Remote branch:" $remote "$status";
    fi
}

# Number of commits ahead/behind master
remoteStatus() {
    # get current commit hash
    currentHash=$(git rev-parse HEAD 2> /dev/null);

    # get remote name
    remote=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null);

    # get commit list between current commit and remote branch
    commitsDiff="$(git log --pretty=oneline --topo-order --left-right $currentHash...$remote 2> /dev/null)";

    # get number of commit ahead/behind current commit
    ahead=$(\grep -c "^<" <<< "$commitsDiff");
    behind=$(\grep -c "^>" <<< "$commitsDiff");

    # prepare status string
    status="";
    if [ $ahead -eq 1 ]; then
        status+=$(trim "$ahead")" ahead";
    elif [ $ahead -gt 1 ]; then
        status+=$(trim "$ahead")" aheads";
    fi
    if [ $ahead -gt 0 ] && [ $behind -gt 0 ]; then
        status+=", ";
    fi
    if [ $behind -eq 1 ]; then
        status+=$(trim "$behind")" behind";
    elif [ $behind -gt 0 ]; then
        status+=$(trim "$behind")" behinds";
    fi

    echo "$status";
}

# Manage Staged files
staging() {
    # get number of staged files, trim result to convert to integer
    staging=$(git status --porcelain | grep "^[MARD]" | wc -l);
    staging=$(trim "$staging");

    if [ $staging -gt 0 ]; then
        # draw method call for sub-title
        drawLine "Staging";

        # cycling all porcelain status
        git status --porcelain | grep "^[MARD]" | while read -r ; do
            label="";
            diff="";

            # extract first letter only
            status=${REPLY:0:1};

            if [[ $status == "M" ]]; then
                label="  Modified";
                diff=$(diffStat "${REPLY:3}" cached);
            elif [[ $status == "A" ]]; then
                label="  Added";
                diff=$(diffStat "${REPLY:3}" cached);
            elif [[ $status == "R" ]]; then
                label="  Renamed";
                diff="?"
            elif [[ $status == "D" ]]; then
                label="  Deleted";
                diff=$(git diff --stat HEAD | grep ${REPLY:3} | grep -o ' [0-9]\{1,\} ');
                diff=$(trim "$diff")"-";
            # TODO: implement copied files
            fi

            # draw method call for staged status
            drawLine "$label" "${REPLY:3}" "$diff";
        done

        # draw method call for an empty line after staged status block
        drawLine;
    fi
}

# Manage Unstaged files
changes() {
    # get number of unstaged files, trim result to convert to integer
    changes=$(git status --porcelain | grep "^.[MD]" | wc -l);
    changes=$(trim "$changes");

    if [ $changes -gt 0 ]; then
        # draw method call for sub-title
        drawLine "Changes";

        # cycling all porcelain status
        git status --porcelain | grep "^.[MD]" | while read -r ; do
            label="";
            diff="";

            # extract second letter only
            status=${REPLY:1:1};

            if [[ $status == "M" ]]; then
                label="  Modified";
                diff=$(diffStat "${REPLY:3}");
            elif [[ $status == "D" ]]; then
                label="  Deleted";
                diff=$(git diff --stat HEAD | grep ${REPLY:3} | grep -o ' [0-9]\{1,\} ');
                diff=$(trim "$diff")"-";
            fi

            # draw method call for unstaged status
            drawLine "$label" "${REPLY:3}" "$diff";
        done

        # draw method call for an empty line after unstaged status block
        drawLine;
    fi
}

# Manage Untracked files
untracked() {
    # get number of untracked files, trim result to convert to integer
    untracked=$(git status --porcelain -u | grep "^??" | wc -l);
    untracked=$(trim "$untracked");

    if [ $untracked -gt 0 ]; then
        # draw method call for sub-title
        drawLine "Untracked";

        # cycling all porcelain status, use -u to get untracked files in porcelain status
        git status --porcelain -u | grep "^[??]" | while read -r ; do
            label="  Untracked";
            diff=$(cat "${REPLY:3}" | wc -l);

            # draw method call for unstaged status
            drawLine "$label" "${REPLY:3}" "${diff// /}+";
        done

        # draw method call for an empty line after untracked status block
        drawLine;
    fi
}

# Manage clean branch
noWork() {
    # get number of changed files, trim result to convert to integer
    work=$(git status --porcelain | wc -l);
    work=$(trim "$work");

    if [ $work -eq 0 ]; then
        # draw method call for sub-title
        drawLine "No work";

        # draw method call for an empty line after untracked status block
        drawLine;
    fi
}

# Number of commits since master
commits() {
    # cycling through each commit since master
    git log $(git rev-parse --abbrev-ref HEAD) ^master --no-merges --format="%h;%ar;%B" | while read -r ; do
        # check if it's not an empty line (can happened)
        if [[ $REPLY != "" ]]; then
            # get commit infos
            shortHash=$(echo $REPLY | cut -d \; -f 1);
            date=$(echo $REPLY | cut -d \; -f 2);
            message=$(echo $REPLY | cut -d \; -f 3);

            # draw method call
            drawLine "$shortHash" "$message" "$date";
        fi
    done
}



## Utils
# Is this a git repository?
isGitRepository() {
    if [ $(git rev-parse --is-inside-work-tree 2> /dev/null) ]; then
        return 0;
    else
        return 1;
    fi;
}

# Number of changed lines in file
diffStat() {
    diff="";

    # regex for renamed files in git status porcelain (oldName.ext -> newName.ext)
    reg='* -> ';

    # get number of diff lines, use --cached for staged files
    if [ $# -eq 1 ]; then
        diff=$(git diff --shortstat ${1#$reg});
    elif [ $# -eq 2 ]; then
        if [[ $2 == "cached" || $2 == "staged" ]]; then
            diff=$(git diff --cached --shortstat ${1#$reg});
        else
            exit 4;
        fi
    else
        exit 3;
    fi;

    # prepare text
    diff=${diff/ insertion(+),/+};
    diff=${diff/ insertions(+),/+};
    diff=${diff/ insertion(+)/+};
    diff=${diff/ insertions(+)/+};
    diff=${diff/ deletion(-),/-};
    diff=${diff/ deletions(-),/-};
    diff=${diff/ deletion(-)/-};
    diff=${diff/ deletions(-)/-};
    diff=${diff:16};

    echo $(trim "$diff");
}

# Trim space caracters at start/end of string
trim() {
    if [ $# -eq 1 ]; then
        value=${1## };
        echo ${value%% };
    else
        exit 5;
    fi
}

# Print line with special chars
print() {
    if [ $# -eq 1 ]; then
        echo -e "$1";
    else
        exit 2;
    fi;
}



## Run main commande
printGitTable
