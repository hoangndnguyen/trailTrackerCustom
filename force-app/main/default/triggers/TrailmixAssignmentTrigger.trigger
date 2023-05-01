trigger TrailmixAssignmentTrigger on trailheadapp__Trailmix_Assignment__c (after update, after insert) {
    if(Trigger.isAfter){
        if(Trigger.isInsert){
            System.debug('Inserted');
            for(trailheadapp__Trailmix_Assignment__c ta : Trigger.new){
            // Check if the status is good
            System.debug('ta.trailheadapp__Status__c: '+ ta.trailheadapp__Status__c);
        	}
        }
        if(Trigger.isUpdate){
            System.debug('Updated');
            TrailmixAssignmentHelper.assignBadges(Trigger.new);
        }
    }
}