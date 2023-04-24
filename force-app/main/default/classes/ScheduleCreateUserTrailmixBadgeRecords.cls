public with sharing class ScheduleCreateUserTrailmixBadgeRecords implements Schedulable {

    public void execute(SchedulableContext sc){
        Date createdDate = Date.today().addDays(-1);
        Date createdDateMax = Date.today();
        System.debug(createdDate);
        System.debug(createdDateMax);

        // Get the User Trailmix created today and store their Trailmix ID created yesterday
        List<trailheadapp__User_Trailmix__c> userTrailmixes = [SELECT Id, trailheadapp__User__c, trailheadapp__Trailmix__c
                                                            FROM trailheadapp__User_Trailmix__c 
                                                            WHERE CreatedDate >= :createdDate 
                                                            AND CreatedDate < :createdDateMax];

        if(userTrailmixes.size() > 0){
            Set<Id> trailmixId = new Set<Id>();
            Set<Id> userTrailmixId = new Set<Id>();                
            // Map<trailmixid, Set<List<usertrailmixid, userid>>
            Map<Id,Set<List<Id>>> trailMixUserMap = new Map<Id,Set<List<Id>>>();
            for (trailheadapp__User_Trailmix__c ut: userTrailmixes){
                trailmixId.add(ut.trailheadapp__Trailmix__c);
                userTrailmixId.add(ut.Id);
                Set<List<Id>> ids = new Set<List<Id>>();
                List<Id> uids = new List<Id>();
                if(trailMixUserMap.containsKey(ut.trailheadapp__Trailmix__c)){
                    ids = trailMixUserMap.get(ut.trailheadapp__Trailmix__c);
                }
                uids.add(ut.Id);
                uids.add(ut.trailheadapp__User__c);
                ids.add(uids);
                trailMixUserMap.put(ut.trailheadapp__Trailmix__c, ids);
            }
            System.debug('trailMixUserMap size:' + trailMixUserMap.size());
            System.debug('trailMixUserMap: ' + trailMixUserMap);
            
            // Get the User Trailmix Badge from the User Trailmix
            List<User_Trailmix_Badge__c> userTrailmixeBadges = [SELECT Id, User_Badge__c, User_Trailmix__c
                                                                FROM User_Trailmix_Badge__c 
                                                                WHERE User_Trailmix__c in :userTrailmixId];
            // Create a list of User Trailmix Badge (reality)
            List<List<Id>> userTrailBadgeReality = new List<List<Id>>();
            for (User_Trailmix_Badge__c utb: userTrailmixeBadges){
                userTrailBadgeReality.add(new List<Id>{utb.User_Trailmix__c, utb.User_Badge__c});
            }
            System.debug('userTrailmixeBadges size:' + userTrailmixeBadges.size());
            System.debug('userTrailmixeBadges: ' + userTrailmixeBadges); 
            System.debug('userTrailBadgeReality size:' + userTrailBadgeReality.size());
            System.debug('userTrailBadgeReality: ' + userTrailBadgeReality);
                
            // Get the the Trailmix Badges from Trailmix ID and store their Badge ID
            List<Trailmix_Badge__c> trailmixBadges = [SELECT Id, Trailmix__c, Badge__c 
                                                    FROM Trailmix_Badge__c 
                                                    WHERE Trailmix__c in :trailmixId];
            Set<Id> badgeId = new Set<Id>();
            for (Trailmix_Badge__c tb: trailmixBadges){
                badgeId.add(tb.Badge__c);
            }
            System.debug('trailmixBadges size:' + trailmixBadges.size());
            System.debug('trailmixBadges: ' + trailmixBadges);
            System.debug('badgeId size:' + badgeId.size()); System.debug('badgeId: ' + badgeId);
            
            // Get the User Bage from Badge ID
            List<trailheadapp__User_Badge__c> userBadges = [SELECT Id, trailheadapp__Badge__c, trailheadapp__User__c 
                                                            FROM trailheadapp__User_Badge__c 
                                                            WHERE trailheadapp__Badge__c in :badgeId];
            
            // Map<badgeid, Set<List<userbadgeid, userid>>
            Map<Id,Set<List<Id>>> badgeUserMap = new Map<Id,Set<List<Id>>>();
            for(trailheadapp__User_Badge__c ub: userBadges){
                Set<List<Id>> ids = new Set<List<Id>>();
                List<Id> uids = new List<Id>();
                if(badgeUserMap.containsKey(ub.trailheadapp__Badge__c)){
                    ids = badgeUserMap.get(ub.trailheadapp__Badge__c);
                }
                uids.add(ub.Id);
                uids.add(ub.trailheadapp__User__c);
                ids.add(uids);
                badgeUserMap.put(ub.trailheadapp__Badge__c, ids);
            }
            System.debug('badgeUserMap size:' + badgeUserMap.size()); 
            System.debug('badgeUserMap:' + badgeUserMap);

            // Compare and create User Trailmix Badge reality vs expected
            List<User_Trailmix_Badge__c> utbToCreate = new List<User_Trailmix_Badge__c>();
            for(Trailmix_Badge__c tb:  trailmixBadges){
                Set<List<Id>> trailmixUserMap1 = new Set<List<Id>>();
                Set<List<Id>> badgeUserMap1 = new Set<List<Id>>();
                trailmixUserMap1 = trailmixUserMap.get(tb.Trailmix__c); System.debug('trailmixUserMap1: ' + trailmixUserMap1);
                badgeUserMap1 = badgeUserMap.get(tb.Badge__c); System.debug('badgeUserMap1: ' + badgeUserMap1);
                if(trailmixUserMap1.size() == 0 || badgeUserMap1.size() == 0){
                    continue; // userBadge was not created
                }else{
                    for(List<Id> tum: trailmixUserMap1){
                        for(List<Id> bum: badgeUserMap1){
                            if(tum[1] == bum[1]){
                                Boolean found = false;
                                for(Integer i = 0; i< userTrailBadgeReality.size(); i++){
                                    if(userTrailBadgeReality[i][0] == tum[0] && userTrailBadgeReality[i][1] == bum[0]){
                                        found = true;
                                        userTrailBadgeReality.remove(i); // remove it since it already exists
                                        break;
                                    }
                                }
                                if(!found){
                                    utbToCreate.add(new User_Trailmix_Badge__c(User_Trailmix__c = tum[0], User_Badge__c = bum[0]));
                                }
                            }
                        }
                    }
                }
            }

            System.debug('utbToCreate size:' + utbToCreate.size());
            for(User_Trailmix_Badge__c u: utbToCreate){
                System.debug(u);
            }
            
            //Insert User Trailmix Badges 
            Database.SaveResult[] srList = Database.insert(utbToCreate, true);
            
            // Iterate through each returned result
            for (Database.SaveResult sr : srList) {
                if (sr.isSuccess()) {
                    // Operation was successful, so get the ID of the record that was processed
                    System.debug('Successfully inserted account. User Trailmix Badge ID: ' + sr.getId());
                }
                else {
                    // Operation failed, so get all errors                
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');                    
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('User Trailmix Badge fields that affected this error: ' + err.getFields());
                    }
                }
            }
        }else{
            System.debug('No User Trailmix records create yesterday.');
        }
        
    }
    
}