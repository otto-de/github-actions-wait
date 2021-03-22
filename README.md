# Purpose of the github action

_Assumption_ : You are managing cloud infrastructure with terraform remote state in "github actions"

If the same workflow is used by multiple branches or there are multiple commits in the same branch chances are that 
the workflow runs after 1st run might get failed due to not being able to acquire lock on terraform remote state as
1st run is already having the lock in place.

To avoid this issue this github wait action can be placed in the workflow before all 'terraform apply' steps are specified

By doing so the consequent runs will wait till the previous runs are complete.

But when a previous completed run is rerun while there are newer runs in the queue, the newer runs will wait till the rerun is complete.
The rerun will also wait for any run which has already crossed the wait step.  

# Below are the steps to achieve parallel jobs running in github workflow to wait on a particular step

1. Name the step as needed. For example: "Wait for other pipelines"
2. Use the action "otto-de/github-actions-wait@v1.0" with the step name as input as shown below. 
The argument to the script should be the same as step name.
3. Place the wait step/s in the workflow in such places so that the following steps should not run in parallel by other jobs.
   An example of this wait step could be the terraform apply steps which use remote state lock feature. If 2 jobs try to use same remote state the 2nd job will fail. 
4. How the script works is as below:
   1. If the number of running jobs is 1, then there is no other job running, there will not be any waiting
   2. If the number of running jobs is greater than 1, check the number of any jobs which were started before the current job
      1. If there are previous jobs running, wait till all the previous jobs complete
      2. If there are no previous jobs running, then this is a scenario needed for reruns, meaning a rerun of an older job is triggered but there are some newer jobs running as well
         1. For each newer job running, verify if the job has already crossed wait step
            1. If wait step is crossed for any of the newer jobs, then wait the current rerun job till the already running newer job to finish 
            2. If no wait step is crossed for any of the newer jobs, rerun will continue execution without waiting
           
```
  - name: Wait
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    uses: otto-de/github-actions-wait@v1.0
    with:
      step-name: "Wait"
``` 

# Future work

1. Multiple wait steps
2. Consider multiple jobs in the same workflow
