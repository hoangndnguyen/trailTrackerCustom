public with sharing class TrailmixAssignmentHelper {

    //  Creating User Badges upon assigning a Trailmix to a User (Trailmix Assignment)
    public static void createUserBadgeRecords(List<trailheadapp__Trailmix_Assignment__c> trailmixAssignments) {
        // Bulk - Identify the relationship between the Trailmix and Badge for a given Trailmix Assignment 
        // Get the parent Trailmix recordId
        List<List<Id>> userTrailmixList = new List<List<Id>>();
        Set<Id> userIds = new Set<Id>();
        Set<Id> trailmixIds = new Set<Id>();
        for(trailheadapp__Trailmix_Assignment__c ta : trailmixAssignments){
            // Check if the status is good
            System.debug('ta.trailheadapp__Status__c: '+ ta.trailheadapp__Status__c);
            if(ta.trailheadapp__Status__c == 'Processed' && ta.trailheadapp__Status__c != 'Error' && ta.trailheadapp__Status__c != 'Not Processed'){
                userTrailmixList.add(new List<Id>{ta.trailheadapp__User__c, ta.trailheadapp__Trailmix__c});
            	trailmixIds.add(ta.trailheadapp__Trailmix__c);
            	userIds.add(ta.trailheadapp__User__c);
            }
        }
        System.debug('userIds: ' +userIds);
        System.debug('userTrailmixList: ' +userTrailmixList);
        System.debug('trailmixIds: ' +trailmixIds);
        
        // Get the junction records of master objects
        List<Trailmix_Badge__c> trailmixBadges = new List<Trailmix_Badge__c>();
        trailmixBadges =   [SELECT Id, Trailmix__c, Badge__c 
                            FROM Trailmix_Badge__c 
                            WHERE Trailmix__c in :trailmixIds];
        if(trailmixBadges.size()> 0){
            Map<Id, List<Id>> userTrailmixMap = new Map<Id, List<Id>>();
            List<Id> tmId;
            for(Id uId : userIds){
                tmId = new List<Id>();
                for(List<Id> ut : userTrailmixList){
                    if(uId == ut[0]){
                        tmId.add(ut[1]);
                    }
                }
                userTrailmixMap.put(uId, tmId);
            }
            System.debug('userTrailmixMap: ' +userTrailmixMap);
            System.debug('trailmixBadges size: ' +trailmixBadges.size());
        
            Map<Id, Set<Id>> trailmixBadgeMap = new Map<Id, Set<Id>>();
            for(Trailmix_Badge__c tmB : trailmixBadges){
                Set<Id> ids = new Set<Id>();
                if(trailmixBadgeMap.containsKey(tmB.Trailmix__c)){
                    ids = trailmixBadgeMap.get(tmB.Trailmix__c);
                }
                ids.add(tmB.Badge__c);
                trailmixBadgeMap.put(tmB.Trailmix__c, ids);
            }
            System.debug('trailmixBadges: ' +trailmixBadges);
        
            Map<Id, Set<Id>> userBadgeExpectMap = new Map<Id, Set<Id>>();
            for(Id uTM : userTrailmixMap.keySet()){
                for(Id trailmixId : userTrailmixMap.get(uTM)){
                    Set<Id> ids = new Set<Id>();
                    if(userBadgeExpectMap.containsKey(uTM)){
                        ids = userBadgeExpectMap.get(uTM);
                    }
                    for(Id bId: trailmixBadgeMap.get(trailmixId)){
                        ids.add(bId);
                    }
                    userBadgeExpectMap.put(uTM, ids);
                }
            }
            System.debug('userBadgeExpectMap: ' +userBadgeExpectMap);
        
            List<trailheadapp__User_Badge__c> userBadgeReality = new List<trailheadapp__User_Badge__c>();
            userBadgeReality = [SELECT Id, trailheadapp__User__c, trailheadapp__Badge__c 
                                FROM trailheadapp__User_Badge__c
                                WHERE trailheadapp__User__c in : userIds];
            System.debug('userBadgeReality: ' + userBadgeReality);
            Map<Id, Set<Id>> userBadgeRealityMap = new Map<Id, Set<Id>>();
            for(Id uId : userIds){
                for(Integer i = 0; i < userBadgeReality.size(); i++){
                    Set<Id> ids = new Set<Id>();
                    if(userBadgeRealityMap.containsKey(userBadgeReality[i].trailheadapp__User__c)){
                        ids = userBadgeRealityMap.get(uId);
                    }
                    ids.add(userBadgeReality[i].trailheadapp__Badge__c);
                    userBadgeReality.remove(i); // Remove the added user badge
                    i--;
                    userBadgeRealityMap.put(uId, ids);
                }
            }
            System.debug('userBadgeReality: ' + userBadgeReality);
            System.debug('userBadgeRealityMap: ' + userBadgeRealityMap);
        
            Map<Id, Set<Id>> userBadgeToCreateMap = new Map<Id, Set<Id>>();
            for(Id uId : userBadgeExpectMap.keySet()){
                for(Id bId : userBadgeExpectMap.get(uId)){
                    if(userBadgeRealityMap.containsKey(uId)){
                        if(!userBadgeRealityMap.get(uId).contains(bId)){
                            Set<Id> ids = new Set<Id>();
                            if(userBadgeToCreateMap.containsKey(uId)){
                                ids = userBadgeToCreateMap.get(uId);
                            }
                            ids.add(bId);
                            userBadgeToCreateMap.put(uId, ids);
                        }
                    }else{
                        Set<Id> ids = new Set<Id>();
                        if(userBadgeToCreateMap.containsKey(uId)){
                            ids = userBadgeToCreateMap.get(uId);
                        }
                        ids.add(bId);
                        userBadgeToCreateMap.put(uId, ids);
                    }
                }
            }
            System.debug('userBadgeToCreateMap: ' + userBadgeToCreateMap);
        
            List<trailheadapp__User_Badge__c> userBadgesToCreate = new List<trailheadapp__User_Badge__c>();
            for(Id uId : userBadgeToCreateMap.keySet()){
                for(Id bId : userBadgeToCreateMap.get(uId)){
                    userBadgesToCreate.add(new trailheadapp__User_Badge__c(trailheadapp__Status__c = 'Assigned', trailheadapp__User__c = uId, trailheadapp__Badge__c = bId));
                }    
            }
            System.debug('userBadgesToCreate: ' + userBadgesToCreate);
        
            //Insert userBadgesToCreate;
            Database.SaveResult[] srList = Database.insert(userBadgesToCreate, true);

            // Iterate through each returned result
            for (Database.SaveResult sr : srList) {
                if (sr.isSuccess()) {
                    // Operation was successful, so get the ID of the record that was processed
                    System.debug('Successfully inserted account. User Badge ID: ' + sr.getId());
                }
                else {
                    // Operation failed, so get all errors                
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');                    
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('User Badge fields that affected this error: ' + err.getFields());
                    }
                }
            }
        }else{
            System.debug('No junction records of master objects');
        }
        
    } //End of createUserBadgeRecords method
    
}