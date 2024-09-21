#!/usr/bin/bash

extract_pr_email() {
    pr_id="$1"

    pr_details=$(aws codecommit get-pull-request --pull-request-id "$pr_id" --query "pullRequest.authorArn" --output text)
}

execute_change_set() {
    stack_name="$1"
    change_set_name="$2"

    # Executes the change set.
    aws cloudformation execute-change-set --region "$AWS_REGION" --stack-name "$stack_name" --change-set-name "$change_set_name"

    while true; do
        # Queries the execution status of the change set.
        execution_status=$(aws cloudformation describe-change-set --region "$AWS_REGION" --stack-name "$stack_name" --change-set-name "$change_set_name" --query "ExecutionStatus" --output text 2>/dev/null || echo "NOT_FOUND")

        case $execution_status in

            stack_status=$(aws cloudformation describe-stacks --region "$AWS_REGION" --stack-name "$stack_name" --query "Stacks[0].StackStatus" --output text)
            echo "Change set not found. Checking stack status: $stack_status"
            if [[ "$stack_status" == "UPDATE_COMPLETE" ]]; then
                echo "Stack update was applied successfully."
                return 0
            elif [[ "$stack_status" == "UPDATE_ROLLBACK_COMPLETE" ]]; then
                echo "Stack update failed."
                return 1
            else
                echo "Change set not found and stack status is not complete: $stack_status"
                return 1
            fi
            ;;
        *)
            echo "Unknown status, handling as error."
            return 1
            ;;
        esac
    done
}