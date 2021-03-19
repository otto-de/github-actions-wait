#! /usr/bin/env bash

set -exo pipefail

if [ -z "$*" ] || [ "$#" != 1 ]; then
  echo "Only 1 input \"the step name\" is required as argument to the script. Number of arguments present are $#"
  echo "Arguments received are $*"
  exit 1
fi

step_name=$1

echo "DEBUGGING: step_name is $step_name"

SCRIPT_DIR="$(cd "$(dirname "$0")" ; pwd -P)"
echo "Script dir is $SCRIPT_DIR"

echo "DEBUGGING: beginning"

GITHUB_WORKFLOW_URL=$(curl -sH "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}" | \
  jq -r '.workflow_url')

# Show the current run_number of the workflow run
echo "CURRENT_RUN_NUMBER is ${GITHUB_RUN_NUMBER}"

run_while=true

while [ $run_while ];
do
  # If the number of runs is 1 then no further checking is needed
  IN_PROGRESS_RUNNING=$(curl -sH "Authorization: Bearer ${GITHUB_TOKEN}" \
    "${GITHUB_WORKFLOW_URL}/runs" | \
    jq -r ".workflow_runs[] | select(.status == \"in_progress\")| .id" | wc -l)

  echo "IN_PROGRESS_RUNNING is $IN_PROGRESS_RUNNING"

  if [[ $IN_PROGRESS_RUNNING -eq 1 ]]; then
    echo "No further checking is required. break"
    run_while=false
    break
  else
    # Get the number of workflows which are started before the current run
    IN_PROGRESS_PREVIOUS=$(curl -sH "Authorization: Bearer ${GITHUB_TOKEN}" \
      "${GITHUB_WORKFLOW_URL}/runs" | \
      jq -r ".workflow_runs[] | select((.status == \"in_progress\") and (.run_number < ${GITHUB_RUN_NUMBER}))| .id" | wc -l)

    echo "IN_PROGRESS_PREVIOUS is $IN_PROGRESS_PREVIOUS"

    if [[ $IN_PROGRESS_PREVIOUS -gt 0 ]]; then
      echo "Previous runs are still running. Waiting for 10 seconds"
      sleep 10
    else
      echo "Validate for rerun. Better to use != than > since != would also \
        consider any new previous run as well"
      IN_PROGRESS_OTHER=$(curl -sH "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${GITHUB_WORKFLOW_URL}/runs" | \
        jq -r ".workflow_runs[] | select((.status == \"in_progress\") and (.run_number != ${GITHUB_RUN_NUMBER}))| .id")

      echo "IN_PROGRESS_OTHER is $IN_PROGRESS_OTHER"

      IN_PROGRESS_OTHER_COUNT="${#IN_PROGRESS_OTHER[@]}"

      if [[ $IN_PROGRESS_OTHER_COUNT -gt 0 ]]; then
        echo "Wait till all other runs which have crossed wait action to complete"

        for id in $IN_PROGRESS_OTHER ; do
        # Get the run id of the run which is currently running terraform commands
        IN_PROGRESS_ID_RUNNING=$(curl -sH "Authorization: Bearer ${GITHUB_TOKEN}" \
          "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runs/$id/jobs" | \
          jq -r ".jobs[].steps[] | select((.status == \"completed\") and (.name == \"$step_name\"))| .name" | wc -l)

        if [[ $IN_PROGRESS_ID_RUNNING -gt 0 ]]; then
          echo "DEBUGGING: Have to wait till the run status of the run with id $id is completed"

          echo "DEBUGGING: Get the status of the run with id $id"

          run_inner_while=true

          while [ $run_inner_while ]; do
            IN_PROGRESS_ID_STATUS=$(curl -sH "Authorization: Bearer ${GITHUB_TOKEN}" \
              "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runs/$id" | \
              jq -r ". | \
              select(.status == \"completed\")| .id" | wc -l)

            echo "verify if the already running github run is completed"

            if [[ IN_PROGRESS_ID_STATUS -eq 1 ]]; then
              echo "Workflow run with id $id is completed. break"
              run_inner_while=false
              break
            else
              echo "Workflow run with id $id is not yet completed. Waiting for 10 seconds"
              sleep 10
            fi
          done
        else
          echo "For the run with id $id, the $step_name step is not completed. Continue \
            probing other run ids which are in progress."
          continue
        fi

      done
      echo "There is no other run running which has crossed waitforpipeline step. break"
      run_while=false
      break

      else
        echo "No other run is in progress. break"
        run_while=false
        break
      fi

    fi

  fi

done
