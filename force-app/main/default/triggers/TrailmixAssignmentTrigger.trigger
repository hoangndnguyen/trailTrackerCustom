trigger TrailmixAssignmentTrigger on trailheadapp__Trailmix_Assignment__c (after insert) {
    if(Trigger.isAfter){
        if(Trigger.isInsert){
            TrailmixAssignmentHelper.createUserBadgeRecords(Trigger.new);
        }
    }
}