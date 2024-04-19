// Issue here. Plan and plan execution are created in San Jose region
// When you create a plan execution, it will execute the plan in the target region
// automatically after creation.
// After plan execution is completed which is an equivalent of clicking
// "Run prechecks" button in the video
// San Jose region which has "Standby" role will become "Primary" and Ashburn region
// will become "standby"

// Don't know why, seems that internal implementation has some interesting logic.


variable "sjc_protection_group_id" {}
variable "ashburn_fsdr" {}

resource "oci_disaster_recovery_dr_plan" "sjc_fsdr_plan" {
  display_name           = "mushop-app-switchover"
  dr_protection_group_id = var.sjc_protection_group_id
  type                   = "SWITCHOVER"
  // silly trick to deal with circular dependency
  depends_on = [var.ashburn_fsdr]
}

// After plan execution is completed
// San Jose region which has "Standby" role will become "Primary" and Ashburn region
// will become "Standby"
// This is ok, as following block really executes DR plan
// and moves resources to backup region.

// Also, when you create plan without plan execution,
// you can click "Run prechecks" button manually as in video

// takes about 7 - 10 min to create
// as it executes the plan during creation

/*
resource "oci_disaster_recovery_dr_plan_execution" "fsdr_plan_execution" {
    execution_options {
      plan_execution_type = "SWITCHOVER"
      are_prechecks_enabled = true
      are_warnings_ignored = true
    }
    plan_id = oci_disaster_recovery_dr_plan.sjc_fsdr_plan.id
    display_name = "mushop-app-switchover-execution"
  // silly trick to deal with circular dependency
  depends_on = [var.ashburn_fsdr]
}
*/