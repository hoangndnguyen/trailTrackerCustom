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
            System.debug('assignment.trailheadapp__Status__c: '+ assignment.trailheadapp__Status__c);
            if(assignment.trailheadapp__Status__c == 'Processed'){
            	trailmixIds.add(assignment.trailheadapp__Trailmix__c);
            	userIds.add(assignment.trailheadapp__User__c);
            }
        }
        System.debug('userIds: ' +userIds);
        System.debug('trailmixIds: ' +trailmixIds);
        Map<Id, Set<Id>> trailmixBadgesMap = getTrailmixBadges(trailmixIds);
        if(trailmixBadgesMap.size() <= 0){
            System.debug('No junction records of master objects.');
            return;
        }

        Map<Id, Set<List<Id>>> userTrailmixRealityMap =  constructUserTrailmixMap(userIds);
        System.debug('-----------------userTrailmixRealityMap: ' );
        for(Id id: userTrailmixRealityMap.keySet()){
            System.debug('userTrailmixRealityMap: ' + id);
            System.debug(userTrailmixRealityMap.get(id));
        }
        System.debug('userTrailmixRealityMap size: ' + userTrailmixRealityMap.size());

        List<trailheadapp__User_Badge__c> userBadges = [SELECT Id, trailheadapp__User__c,trailheadapp__Badge__c FROM trailheadapp__User_Badge__c WHERE trailheadapp__User__c in :userIds];
        if(userBadges.size() <= 0){
            System.debug('No User Badge records found.');
            return;
        }
        System.debug('userBadges size: ' + userBadges.size());
        System.debug('userBadges: ' + userBadges);

        Map<Id, Set<List<Id>>> userBadgeRealityMap =  constructUserBadgeMap(userBadges);
        System.debug('-----------------userBadgeRealityMap: ' );
        for(Id id: userBadgeRealityMap.keySet()){
            System.debug('userBadgeRealityMap: ' + id);
            System.debug(userBadgeRealityMap.get(id));
        }
        System.debug('userBadgeRealityMap size: ' + userBadgeRealityMap.size());

        
        List<List<Id>> userTrailmixBadgeTarget = createUserTrailmixBadgeTarget(userIds, userTrailmixRealityMap, userBadgeRealityMap);
        
        List<List<Id>> userTrailmixBadgeToCreateList = compareRealityVsExpected(userTrailmixBadgeTarget);

        List<User_Trailmix_Badge__c> userTrailmixBadgeToCreate = constructUserTrailmixBadge(userTrailmixBadgeToCreate);

        if (!userTrailmixBadgeToCreate.isEmpty()) {           
            insert userTrailmixBadgeToCreate;
        }
        
    }

    public List<trailheadapp__Trailmix_Assignment__c> getTrailmixAssigmentCreated(){
        Date createdDate = Date.today().addDays(-1);
        Datetime createdDateMax = Datetime.now();
        System.debug(createdDate);
        System.debug(createdDateMax);

        List<trailheadapp__Trailmix_Assignment__c> trailmixAssignments = [SELECT Id, trailheadapp__Trailmix__c, trailheadapp__User__c, trailheadapp__Status__c FROM trailheadapp__Trailmix_Assignment__c 
                                                       WHERE CreatedDate >= :createdDate 
                                                       AND CreatedDate < :createdDateMax];

        if(trailmixAssignments.size() > 0){
            return trailmixAssignments;
        }
        return null;
    }

    /**
     * Return a map of Trailmix Badge master junction records
     * trailmixIds: the Trailmixes' Id from Trailmix Assignments 
     */
    private static Map<Id, Set<Id>> getTrailmixBadges(Set<Id> trailmixIds){
        List<Trailmix_Badge__c> trailmixBadges = [SELECT Id, Trailmix__c, Badge__c 
                                                  FROM Trailmix_Badge__c 
                                                  WHERE Trailmix__c in :trailmixIds];
        if(trailmixBadges.size()<= 0){
            System.debug('No trailmixBadges data found.');
            return null;
        }
        // Trailmix Id, Set of Badge Ids
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

        System.debug('trailmixBadgeMap: ' +trailmixBadgeMap);
        return trailmixBadgeMap;                           
    }

    /**
     * Return a map of Trailmix Badge master junction records
     * trailmixIds: the Trailmixes' Id from Trailmix Assignments 
     */
    private static Map<Id, Set<List<Id>>> constructUserTrailmixMap(Set<Id> userIds){
        List<trailheadapp__User_Trailmix__c> userTrailmixes = [SELECT Id, trailheadapp__User__c,trailheadapp__Trailmix__c FROM trailheadapp__User_Trailmix__c WHERE trailheadapp__User__c in :userIds];
        if(userTrailmixes.size()<= 0){
            return null;
        }else{
            // userId, [trailmixid, userTraimixid]
            Map<Id, Set<List<Id>>> userTrailmixRealityMap = new Map<Id, Set<List<Id>>>();
            for(trailheadapp__User_Trailmix__c userTrailmix : userTrailmixes){
                Set<List<Id>> idSet = userTrailmixRealityMap.get(userTrailmix.trailheadapp__User__c);
                if(idSet == null){
                    idSet = new Set<List<Id>>{new List<Id>{userTrailmix.trailheadapp__Trailmix__c, userTrailmix.Id}};
                }else{
                    idSet.add(new List<Id>{userTrailmix.trailheadapp__Trailmix__c, userTrailmix.Id});
                }
                userTrailmixRealityMap.put(userTrailmix.trailheadapp__User__c, idSet);
            }
            return userTrailmixRealityMap;
        }                           
    }

    /**
     * Return a map of Trailmix Badge master junction records
     * trailmixIds: the Trailmixes' Id from Trailmix Assignments 
     */
    private static Map<Id, Set<List<Id>>> constructUserBadgeMap(List<trailheadapp__User_Badge__c> userBadges){
        if(userBadges.size() <= 0){
            return null;
        }
        Map<Id, Set<List<Id>>> userBadgeRealityMap = new Map<Id, Set<List<Id>>>();
            for(trailheadapp__User_Badge__c userBadge : userBadges){
                Set<List<Id>> idSet = userBadgeRealityMap.get(userBadge.trailheadapp__User__c);
                if(idSet == null){
                    idSet = new Set<List<Id>>{new List<Id>{userBadge.trailheadapp__Badge__c, userBadge.Id}};
                }else{
                    idSet.add(new List<Id>{userBadge.trailheadapp__Badge__c, userBadge.Id});
                }
                userBadgeRealityMap.put(userBadge.trailheadapp__User__c, idSet);
            }
        return userBadgeRealityMap;                      
    }

    /**
     * Return a map of Trailmix Badge master junction records
     * trailmixIds: the Trailmixes' Id from Trailmix Assignments 
     */
    private static Set<List<Id>> getUserTrailmixBadgeReality(List<trailheadapp__User_Badge__c> userBadges){
        
        Set<Id> userBadgeIds = new Set<Id>();
        for(trailheadapp__User_Badge__c userBadge : userBadges){
            userBadgeIds.add(userBadge.Id);
        }

        List<User_Trailmix_Badge__c> userTrailmixBadgeReality = [SELECT Id, User_Trailmix__c, User_Badge__c FROM User_Trailmix_Badge__c WHERE User_Badge__c in :userBadgeIds];
        if(userTrailmixBadgeReality.size() <= 0){
            System.debug('No userTrailmixBadgeReality found!');
            return null;
        }

        //Set of [User Trailmix Id, User Badge Id]
        Set<List<Id>> userTrailmixBadgeRealitySet = new Set<List<Id>>();

        for(User_Trailmix_Badge__c userTrailmixBadge : userTrailmixBadgeReality){
            userTrailmixBadgeRealitySet.add(new List<Id>{userTrailmixBadge.User_Trailmix__c, userTrailmixBadge.User_Badge__c});
        }

        System.debug('userTrailmixBadgeRealitySet: ' + userTrailmixBadgeRealitySet);
        return userTrailmixBadgeRealitySet;                      
    }

    /**
     * Return a list of User Badge records that need to be created for all users
     * trailmixBadgeMap: the map of badges (value) belongs to a trailmix (key)
     * userBadgeRealityMap: the map of badges (value) assigned to each user (key)
     * trailmixIds: the set of Trailmix Ids
     * userIds: the set of User Ids
     */
    private static List<List<Id>> createUserTrailmixBadgeTarget(Set<Id> userIds, Map<Id,Set<List<Id>>> userTrailmixRealityMap, Map<Id,  Set<List<Id>>> userBadgeRealityMap){
        List<List<Id>> userTrailmixBadgeToCreateSet = new List<List<Id>>();
        for (Id userId : userIds){
            // trailmixid, usertrailmix id
            Set<List<Id>> userTrailmixSubSet = userTrailmixRealityMap.get(userId);
            System.debug('userTrailmixSubSet size: ' + userTrailmixSubSet.size());
            System.debug('userTrailmixSubSet: ' + userTrailmixSubSet);
            // badgeid, userbadge id
            Set<List<Id>> userBadgeSubSet = userBadgeRealityMap.get(userId);
            System.debug('userBadgeSubSet size: ' + userBadgeSubSet.size());
            System.debug('userBadgeSubSet: ' + userBadgeSubSet);

            Map<Id, Id> userTrailmixMapByTrailmix = new Map<Id, Id>();
            for (List<Id> userTrailmixList: userTrailmixSubSet){
                userTrailmixMapByTrailmix.put(userTrailmixList[0], userTrailmixList[1]);
            }

            Map<Id, Id> userBadgeMapByBadge = new Map<Id, Id>();
            for (List<Id> userBadgeList: userBadgeSubSet){
                userBadgeMapByBadge.put(userBadgeList[0], userBadgeList[1]);
            }

            for(Id trailmixId: userTrailmixMapByTrailmix.keySet()){
                Set<Id> badgeIdsTarget = trailmixBadgesMap.get(trailmixId);
                if(badgeIdsTarget == null){
                    continue;
                }
                for(Id badgeId : badgeIdsTarget){
                    userTrailmixBadgeToCreateSet.add(new List<Id>{userTrailmixMapByTrailmix.get(trailmixId), userBadgeMapByBadge.get(badgeId)});
                }    
            }
        }
        return userTrailmixBadgeToCreateSet;
    }

    /**
     * Return a list of User Badge records that need to be created for a specific user
     * badgeExpected: the set of badges that the user should to be assigned
     * badgeReality: the set of badges that the user is assigned 
     * userId: the User's Id
     */
    private static List<List<Id>> compareRealityVsExpected(List<List<Id>> userTrailmixBadgeToCreateSet){
        Set<List<Id>> userTrailmixBadgesReality = getUserTrailmixBadgeReality(userBadges);
        if(userTrailmixBadgesReality != null){
            System.debug('+++++++++++++++++++++not null: ');
            for(List<Id> idsReality : userTrailmixBadgesReality){
                for(Integer i = 0; i< userTrailmixBadgeToCreateSet.size(); i++){
                    if(userTrailmixBadgeToCreateSet[i][0] == idsReality[0] && userTrailmixBadgeToCreateSet[i][1] == idsReality[1]){
                        userTrailmixBadgeToCreateSet.remove(i);
                    }
                }
            }
        }
        return userTrailmixBadgeToCreateSet;
    }

    /**
     * Return a list of User Badge records that need to be created for a specific user
     * badgeExpected: the set of badges that the user should to be assigned
     * badgeReality: the set of badges that the user is assigned 
     * userId: the User's Id
     */
    private static List<User_Trailmix_Badge__c> constructUserTrailmixBadge(List<List<Id>> userTrailmixBadgeToCreateSet){
        List<User_Trailmix_Badge__c> userTrailmixBadges = new List<User_Trailmix_Badge__c>();
        for(List<Id> ids : userTrailmixBadgeToCreateSet){
            userTrailmixBadges.add(new User_Trailmix_Badge__c(User_Trailmix__c = ids[0], User_Badge__c = ids[1]));
        }
        return userTrailmixBadges;
    }
    
}