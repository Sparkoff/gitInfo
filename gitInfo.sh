#!/bin/bash


printGitTable() {
    if isGitRepository; then
        drawSeparator;
        drawSeparator "Repository: "$(basename "$PWD");
        branchName;
        stash;
        remoteName;
        drawLine
        drawSeparator;
        drawSeparator "Working";
        staging;
        changes;
        untracked;
        noWork;
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

drawSeparator() {
    width=$(tput cols);
    if [ $# -eq 1 ]; then
        line="\033[35m|";
        line+="\033[46m\033[37m";
        space=$(( width - 2 - ${#1} ));
        space=$(( space / 2 ));
        for ((i=0; i<$((space)); i++)); do
            line+=" ";
        done
        line+="$1";
        for ((i=0; i<$((width - 2 - $space - ${#1})); i++)); do
            line+=" ";
        done
        line+="\033[0m\033[35m|\033[0m";
        print "$line";
    else
        line="\033[35m+";
        for ((i=0; i<$((width - 2)); i++)); do
            line+="-";
        done
        line+="+\033[0m";
        print $line;
    fi;
}

drawLine() {
    width=$(tput cols);
    line="\033[35m|\033[0m ";
    firstColumnSize=18;
    thirdColumnSize=22;


    if [ $# -eq 1 ]; then
        if [[ $1 == "Staging" ]]; then
            line+="\033[32m$1\033[0m";
        elif [[ $1 == "Changes" ]]; then
            line+="\033[31m$1\033[0m";
        elif [[ $1 == "Untracked" ]]; then
            line+="\033[31m$1\033[0m";
        else
            line+="$1";
        fi

        for ((i=0; i<$((width - 3 - ${#1})); i++)); do
            line+=" ";
        done
    elif [ $# -ge 2 ]; then
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

        line+="$1";
        for ((i=0; i<$((firstColumnSize - ${#1})); i++)); do
            line+=" ";
        done

        line+="$2";
        if [ $# -eq 3 ]; then
            if [ ${#3} -gt $thirdColumnSize ]; then
                if [ ${#3} -gt 15 ]; then
                    thirdColumnSize=18;
                else
                    thirdColumnSize=15;
                fi
            fi

            for ((i=0; i<$((width - 3 - firstColumnSize - ${#2} - thirdColumnSize)); i++)); do
                line+=" ";
            done

            diff=$(statusDiff "$3");
            status=$(statusRemote "$3");

            if [[ $diff != "" ]]; then
                line+="$diff";
            elif [[ $status != "" ]]; then
                line+="$status";
            else
                line+="$3";
            fi

            for ((i=0; i<$((thirdColumnSize - ${#3})); i++)); do
                line+=" ";
            done
        else
            for ((i=0; i<$((width - 3 - firstColumnSize - ${#2})); i++)); do
                line+=" ";
            done
        fi
    else
        for ((i=0; i<$((width - 3)); i++)); do
            line+=" ";
        done
    fi;

    line+="\033[35m|\033[0m";
    print "$line";
}

statusDiff() {
    diff="";
    diffPlus=$(echo $1 | grep -o "[0-9]\{1,\}+");
    diffMoins=$(echo $1 | grep -o "[0-9]\{1,\}-");
    if [[ $diffPlus != "" ]]; then
        diff+="\033[32m$diffPlus\033[0m";
    fi
    if [[ $diffMoins != "" ]]; then
        if [[ $diffPlus != "" ]]; then
            diff+=" ";
        fi
        diff+="\033[31m$diffMoins\033[0m";
    fi
    echo $diff
}

statusRemote() {
    status="";
    statusPlus=$(echo $1 | grep -o "[0-9]\{1,\} ahead[s]\{0,1\}");
    statusMoins=$(echo $1 | grep -o "[0-9]\{1,\} behind[s]\{0,1\}");
    if [[ $statusPlus != "" ]]; then
        status+="\033[32m$statusPlus\033[0m";
    fi
    if [[ $statusMoins != "" ]]; then
        if [[ $statusPlus != "" ]]; then
            status+=", ";
        fi
        status+="\033[31m$statusMoins\033[0m";
    fi
    echo $status
}

branchName() {
    branch=$(git rev-parse --abbrev-ref HEAD);
    tag=$(tag);
    if [[ $tag != "" ]]; then
        tag="Tag: "$tag;
    fi
    drawLine "Current branch:" $branch "$tag";
}

tag() {
    currentHash=$(git rev-parse HEAD 2> /dev/null);
    tag=$(git describe --exact-match --tags $currentHash 2> /dev/null);
    if [[ -n ${tag} ]]; then
        echo $tag;
    else
        echo "";
    fi
}

stash() {
    branch=$(git rev-parse --abbrev-ref HEAD);
    stashes=$(git stash list | grep "on $branch" | wc -l);
    stashes=$(trim "$stashes");
    if [ $stashes -gt 0 ]; then
        drawLine "" "$stashes stashed";
    fi
}

remoteName() {
    remote=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null);
    if [[ -n "${remote}" && "${remote}" != "@{upstream}" ]]; then
        status=$(remoteStatus);
        drawLine "Remote branch:" $remote "$status";
    fi
}

remoteStatus() {
    remote=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null);
    currentHash=$(git rev-parse HEAD 2> /dev/null);
    commitsDiff="$(git log --pretty=oneline --topo-order --left-right $currentHash...$remote 2> /dev/null)";
    ahead=$(\grep -c "^<" <<< "$commitsDiff");
    behind=$(\grep -c "^>" <<< "$commitsDiff");
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

staging() {
    staging=$(git status --porcelain | grep "^[MARD]" | wc -l);
    staging=$(trim "$staging");
    if [ $staging -gt 0 ]; then
        drawLine "Staging";
        git status --porcelain | grep "^[MARD]" | while read -r ; do
            label="";
            status=${REPLY:0:1};
            diff="";
            if [[ $status == "M" ]]; then
                label="  Modified";
                diff=$(diffStat cached "${REPLY:3}");
            elif [[ $status == "A" ]]; then
                label="  Added";
                diff=$(diffStat cached "${REPLY:3}");
            elif [[ $status == "R" ]]; then
                label="  Renamed";
                diff="?"
            elif [[ $status == "D" ]]; then
                label="  Deleted";
                diff=$(git diff --stat HEAD | grep ${REPLY:3} | grep -o ' [0-9]\{1,\} ');
                diff=$(trim "$diff")"-";
            fi
            drawLine "$label" "${REPLY:3}" "$diff";
        done
        drawLine;
    fi
}

changes() {
    changes=$(git status --porcelain | grep "^.[MD]" | wc -l);
    changes=$(trim "$changes");
    if [ $changes -gt 0 ]; then
        drawLine "Changes";
        git status --porcelain | grep "^.[MD]" | while read -r ; do
            label="";
            status=${REPLY:1:1};
            diff="";
            if [[ $status == "M" ]]; then
                label="  Modified";
                diff=$(diffStat "${REPLY:3}");
            elif [[ $status == "D" ]]; then
                label="  Deleted";
                diff=$(git diff --stat HEAD | grep ${REPLY:3} | grep -o ' [0-9]\{1,\} ');
                diff=$(trim "$diff")"-";
            fi
            drawLine "$label" "${REPLY:3}" "$diff";
        done
        drawLine;
    fi
}

untracked() {
    untracked=$(git status --porcelain -u | grep "^??" | wc -l);
    untracked=$(trim "$untracked");
    if [ $untracked -gt 0 ]; then
        drawLine "Untracked";
        git status --porcelain -u | grep "^[??]" | while read -r ; do
            label="  Untracked";
            diff=$(cat "${REPLY:3}" | wc -l);
            drawLine "$label" "${REPLY:3}" "${diff// /}+";
        done
        drawLine;
    fi
}

noWork() {
    work=$(git status --porcelain | wc -l);
    work=$(trim "$work");
    if [ $work -eq 0 ]; then
        drawLine "No work";
        drawLine;
    fi
}

diffStat() {
    diff="";
    reg='* -> ';
    if [ $# -eq 1 ]; then
        diff=$(git diff --shortstat ${1#$reg});
    elif [ $# -eq 2 ]; then
        if [[ $1 == "cached" || $1 == "staged" ]]; then
            diff=$(git diff --cached --shortstat ${2#$reg});
        else
            exit 4;
        fi
    else
        exit 3;
    fi;
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

trim() {
    if [ $# -eq 1 ]; then
        value=${1## };
        echo ${value%% };
    else
        exit 5;
    fi
}

commits() {
    git log $(git rev-parse --abbrev-ref HEAD) ^master --no-merges --format="%h;%ar;%B" | while read -r ; do
        if [[ $REPLY != "" ]]; then
            shortHash=$(echo $REPLY | cut -d \; -f 1);
            date=$(echo $REPLY | cut -d \; -f 2);
            message=$(echo $REPLY | cut -d \; -f 3);
            drawLine "$shortHash" "$message" "$date";
        fi
    done
}

isGitRepository() {
    if [ $(git rev-parse --is-inside-work-tree 2> /dev/null) ]; then
        return 0;
    else
        return 1;
    fi;
}

print() {
    if [ $# -eq 1 ]; then
        echo -e "$1";
    else
        exit 2;
    fi;
}


printGitTable
