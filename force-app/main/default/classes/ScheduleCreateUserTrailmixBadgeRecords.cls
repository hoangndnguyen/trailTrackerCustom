public with sharing class ScheduleCreateUserTrailmixBadgeRecords implements Schedulable {

    public void execute(SchedulableContext sc){
        List<trailheadapp__Trailmix_Assignment__c> trailmixAssignments = getTrailmixAssigmentCreated();
        if(trailmixAssignments == null){
            System.debug('No new Trailmix Assignment records created yesterday.');
            return;
        }
        Set<Id> userIds = new Set<Id>();
        Set<Id> trailmixIds = new Set<Id>();
        for(trailheadapp__Trailmix_Assignment__c assignment : trailmixAssignments){
            // Check if the status is good
            if(assignment.trailheadapp__Status__c == 'Processed'){
            	trailmixIds.add(assignment.trailheadapp__Trailmix__c);
            	userIds.add(assignment.trailheadapp__User__c);
            }
        }

        Map<Id, Set<Id>> trailmixBadgesMap = getTrailmixBadges(trailmixIds);
        if(trailmixBadgesMap.size() <= 0){
            System.debug('No junction records of master objects.');
            return;
        }

        Map<Id, Set<List<Id>>> userTrailmixRealityMap =  constructUserTrailmixMap(userIds);

        List<trailheadapp__User_Badge__c> userBadges = [SELECT Id, trailheadapp__User__c,trailheadapp__Badge__c FROM trailheadapp__User_Badge__c WHERE trailheadapp__User__c in :userIds];
        if(userBadges.size() <= 0){
            System.debug('No User Badge records found.');
            return;
        }
        Map<Id, Set<List<Id>>> userBadgeRealityMap =  constructUserBadgeMap(userBadges);

        List<List<Id>> userTrailmixBadgeTarget = createUserTrailmixBadgeTarget(userIds, userTrailmixRealityMap, userBadgeRealityMap, trailmixBadgesMap);
        List<List<Id>> userTrailmixBadgeToCreateList = compareRealityVsExpected(userTrailmixBadgeTarget, userBadges);
        List<User_Trailmix_Badge__c> userTrailmixBadgeToCreate = constructUserTrailmixBadge(userTrailmixBadgeToCreateList);
        System.debug('userTrailmixBadgeToCreate size: ' + userTrailmixBadgeToCreate.size());
        System.debug('userTrailmixBadgeToCreate: ' + userTrailmixBadgeToCreate);

        if (!userTrailmixBadgeToCreate.isEmpty()) {           
            insert userTrailmixBadgeToCreate;
        }
    }

    /**
     * Return a list of Trailmix Assignment records created from yesterday until now
     */
    public List<trailheadapp__Trailmix_Assignment__c> getTrailmixAssigmentCreated(){
        Date createdDate = Date.today().addDays(-1);
        Datetime createdDateMax = Datetime.now();

        List<trailheadapp__Trailmix_Assignment__c> trailmixAssignments = [SELECT Id, trailheadapp__Trailmix__c, trailheadapp__User__c, trailheadapp__Status__c FROM trailheadapp__Trailmix_Assignment__c 
                                                       WHERE CreatedDate >= :createdDate 
                                                       AND CreatedDate < :createdDateMax];

        if(trailmixAssignments.size() <= 0){
            return null;
        }
        return trailmixAssignments;
    }

    /**
     * Return a map of Trailmix Badge junction records
     * trailmixIds: the set of Trailmix Ids from Trailmix Assignments 
     */
    private static Map<Id, Set<Id>> getTrailmixBadges(Set<Id> trailmixIds){
        List<Trailmix_Badge__c> trailmixBadges = [SELECT Id, Trailmix__c, Badge__c 
                                                  FROM Trailmix_Badge__c 
                                                  WHERE Trailmix__c in :trailmixIds];
        if(trailmixBadges.size() <= 0){
            return null;
        }
        // key: Trailmix Id, value: Set of Badge Ids
        Map<Id, Set<Id>> trailmixBadgeMap = new Map<Id, Set<Id>>();
        for(Trailmix_Badge__c trailmixBadge : trailmixBadges){
            Set<Id> badgeId = trailmixBadgeMap.get(trailmixBadge.Trailmix__c);
            if(badgeId == null){
                badgeId = new Set<Id>{trailmixBadge.Badge__c};
            }else{
                badgeId.add(trailmixBadge.Badge__c);
            }
            trailmixBadgeMap.put(trailmixBadge.Trailmix__c, badgeId);
        }
        return trailmixBadgeMap;                           
    }

    /**
     * Return a map of User Trailmix records where User Id is the key and set of list (trailmixId, userTraimixid) is the value
     * userIds: the User Ids from Trailmix Assignments 
     */
    private static Map<Id, Set<List<Id>>> constructUserTrailmixMap(Set<Id> userIds){
        List<trailheadapp__User_Trailmix__c> userTrailmixes = [SELECT Id, trailheadapp__User__c,trailheadapp__Trailmix__c FROM trailheadapp__User_Trailmix__c WHERE trailheadapp__User__c in :userIds];
        if(userTrailmixes.size() <= 0){
            return null;
        }
        // userId, Set (trailmixid, userTraimixid)
        Map<Id, Set<List<Id>>> userTrailmixMap = new Map<Id, Set<List<Id>>>();
        for(trailheadapp__User_Trailmix__c userTrailmix : userTrailmixes){
            Set<List<Id>> idsSet = userTrailmixMap.get(userTrailmix.trailheadapp__User__c);
            if(idsSet == null){
                idsSet = new Set<List<Id>>{new List<Id>{userTrailmix.trailheadapp__Trailmix__c, userTrailmix.Id}};
            }else{
                idsSet.add(new List<Id>{userTrailmix.trailheadapp__Trailmix__c, userTrailmix.Id});
            }
            userTrailmixMap.put(userTrailmix.trailheadapp__User__c, idsSet);
        }
        return userTrailmixMap;                           
    }

    /**
     * Return a map of User Badge records where User Id is the key and set of list (badgeId, userBadgeId) is the value
     * userBadges: the list of User Badge records to construct the map 
     */
    private static Map<Id, Set<List<Id>>> constructUserBadgeMap(List<trailheadapp__User_Badge__c> userBadges){
        if(userBadges.size() <= 0){
            return null;
        }
        // key: userid, value: set of list (badgeId, userBadgeId)
        Map<Id, Set<List<Id>>> userBadgeMap = new Map<Id, Set<List<Id>>>();
            for(trailheadapp__User_Badge__c userBadge : userBadges){
                Set<List<Id>> idsSet = userBadgeMap.get(userBadge.trailheadapp__User__c);
                if(idsSet == null){
                    idsSet = new Set<List<Id>>{new List<Id>{userBadge.trailheadapp__Badge__c, userBadge.Id}};
                }else{
                    idsSet.add(new List<Id>{userBadge.trailheadapp__Badge__c, userBadge.Id});
                }
                userBadgeMap.put(userBadge.trailheadapp__User__c, idsSet);
            }
        return userBadgeMap;                      
    }

    /**
     * Return a set of list [userTrailmixId, userBadgeId] of User Trailmix Badge junction records
     * userBadges: the list of User Badge records to get the function records
     */
    private static Set<List<Id>> getUserTrailmixBadgeReality(List<trailheadapp__User_Badge__c> userBadges){
        Set<Id> userBadgeIds = new Set<Id>();
        //Set of List [User Trailmix Id, User Badge Id] for returning
        Set<List<Id>> userTrailmixBadgeRealitySet = new Set<List<Id>>();
        for(trailheadapp__User_Badge__c userBadge : userBadges){
            userBadgeIds.add(userBadge.Id);
        }

        List<User_Trailmix_Badge__c> userTrailmixBadgeReality = [SELECT Id, User_Trailmix__c, User_Badge__c FROM User_Trailmix_Badge__c WHERE User_Badge__c in :userBadgeIds];
        if(userTrailmixBadgeReality.size() <= 0){
            System.debug('No User Trailmix Badge has been created for the Trailmix Assignments!');
            return userTrailmixBadgeRealitySet;
        }

        
        for(User_Trailmix_Badge__c userTrailmixBadge : userTrailmixBadgeReality){
            userTrailmixBadgeRealitySet.add(new List<Id>{userTrailmixBadge.User_Trailmix__c, userTrailmixBadge.User_Badge__c});
        }
        System.debug('userTrailmixBadgeRealitySet: ' + userTrailmixBadgeRealitySet);
        return userTrailmixBadgeRealitySet;                      
    }

    /**
     * Return a list of list (User Trailmix, User Badge) records that should be created
     * userIds: the set of User Ids
     * userTrailmixMap: the map of set of list [trailmixid, usertrailmix id] (value) assigned to a user (key) 
     * userBadgesMap: the map of set of list (badgeid, userbadge id) (value) assigned to a user (key)
     * trailmixBadgeMap: the map of badges (value) belong to a trailmix (key)
     */
    private static List<List<Id>> createUserTrailmixBadgeTarget(Set<Id> userIds, Map<Id,Set<List<Id>>> userTrailmixMap, Map<Id,  Set<List<Id>>> userBadgeMap, Map<Id, Set<Id>> trailmixBadgesMap){
        List<List<Id>> userTrailmixBadgeToCreate = new List<List<Id>>();
        for (Id userId : userIds){
            // set of list (trailmixid, usertrailmix id)
            Set<List<Id>> userTrailmixSubSet = userTrailmixMap.get(userId);
            // set of list (badgeid, userbadge id)
            Set<List<Id>> userBadgeSubSet = userBadgeMap.get(userId);

            Map<Id, Id> userTrailmixMapByTrailmixId = new Map<Id, Id>();
            for (List<Id> userTrailmixList: userTrailmixSubSet){
                userTrailmixMapByTrailmixId.put(userTrailmixList[0], userTrailmixList[1]);
            }

            Map<Id, Id> userBadgeMapByBadgeId = new Map<Id, Id>();
            for (List<Id> userBadgeList: userBadgeSubSet){
                userBadgeMapByBadgeId.put(userBadgeList[0], userBadgeList[1]);
            }

            for(Id trailmixId: userTrailmixMapByTrailmixId.keySet()){
                Set<Id> badgeIdsTarget = trailmixBadgesMap.get(trailmixId);
                if(badgeIdsTarget == null){
                    continue;
                }
                for(Id badgeId : badgeIdsTarget){
                    userTrailmixBadgeToCreate.add(new List<Id>{userTrailmixMapByTrailmixId.get(trailmixId), userBadgeMapByBadgeId.get(badgeId)});
                }    
            }
        }
        return userTrailmixBadgeToCreate;
    }

    /**
     * Return a list of list (User Trailmix, User Badge) records that need to be created after comparing with the existing User Trailmix Badge records 
     * userTrailmixBadgeToCreateSet: the target list of list (User Trailmix, User Badge) records that should be created
     * userBadges: list of User Badge records for getting the existing User Trailmix Badge records
     */
    private static List<List<Id>> compareRealityVsExpected(List<List<Id>> userTrailmixBadgeToCreateSet, List<trailheadapp__User_Badge__c> userBadges){
        Set<List<Id>> userTrailmixBadgesReality = getUserTrailmixBadgeReality(userBadges);
        for(List<Id> idsReality : userTrailmixBadgesReality){
            for(Integer i = 0; i< userTrailmixBadgeToCreateSet.size(); i++){
                if(userTrailmixBadgeToCreateSet[i][0] == idsReality[0] && userTrailmixBadgeToCreateSet[i][1] == idsReality[1]){
                    userTrailmixBadgeToCreateSet.remove(i);
                }
            }
        }
        return userTrailmixBadgeToCreateSet;
    }

    /**
     * Return a list of User Trailmix Badge records that need to be created
     * userTrailmixBadgeToCreateSet: the target list of list (User Trailmix, User Badge) records that should be created
     */
    private static List<User_Trailmix_Badge__c> constructUserTrailmixBadge(List<List<Id>> userTrailmixBadgeToCreateSet){
        List<User_Trailmix_Badge__c> userTrailmixBadges = new List<User_Trailmix_Badge__c>();
        // ids[0]: User Trailmix Id, ids[1]: User Badge Id
        for(List<Id> ids : userTrailmixBadgeToCreateSet){
            // By any reason, User Trailmix or User Badge has not been created
            if(ids[0] == null || ids[1] == null){
                continue;
            }
            userTrailmixBadges.add(new User_Trailmix_Badge__c(User_Trailmix__c = ids[0], User_Badge__c = ids[1]));
        }
        return userTrailmixBadges;
    }
    
}