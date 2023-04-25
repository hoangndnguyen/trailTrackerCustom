public with sharing class TrailmixAssignmentHelper {

    public static void assignBadges(List<trailheadapp__Trailmix_Assignment__c> trailmixAssignments){
        Set<Id> userIds = new Set<Id>();
        Set<Id> trailmixIds = new Set<Id>();
        for(trailheadapp__Trailmix_Assignment__c trailmixAssignment : trailmixAssignments){
            // Check if the status is good
            System.debug('trailmixAssignment.trailheadapp__Status__c: '+ trailmixAssignment.trailheadapp__Status__c);
            if(trailmixAssignment.trailheadapp__Status__c == 'Processed'){
            	trailmixIds.add(trailmixAssignment.trailheadapp__Trailmix__c);
            	userIds.add(trailmixAssignment.trailheadapp__User__c);
            }
        }
        System.debug('userIds: ' +userIds);
        System.debug('trailmixIds: ' +trailmixIds);

        Map<Id, Set<Id>> trailmixBadgeMap = constructTrailmixBadgeMap(trailmixIds);
        if(trailmixBadgeMap == null){
            System.debug('No junction records of master objects');
            return;
        }
        Map<Id, Set<Id>> userBadgeRealityMap = constructUserBadgeRealityMap(userIds);
        List<trailheadapp__User_Badge__c> userBadges = createUserBadge(trailmixBadgeMap, userBadgeRealityMap, trailmixIds, userIds);
        if (!userBadges.isEmpty()) {
            insert userBadges;
        }        
    }

    /**
     * Return a map of Trailmix Badge master junction records
     * trailmixIds: the Trailmixes' Id from Trailmix Assignments 
     */
    private static Map<Id, Set<Id>> constructTrailmixBadgeMap(Set<Id> trailmixIds){
        List<Trailmix_Badge__c> trailmixBadges = [SELECT Id, Trailmix__c, Badge__c 
                                                  FROM Trailmix_Badge__c 
                                                  WHERE Trailmix__c in :trailmixIds];
        if(trailmixBadges.size()<= 0){
            return null;
        }else{
            Map<Id, Set<Id>> trailmixBadgeMap = new Map<Id, Set<Id>>();
            for(Trailmix_Badge__c trailmixBadge : trailmixBadges){
                Set<Id> badgeIds = trailmixBadgeMap.get(trailmixBadge.Trailmix__c);
                if(badgeIds == null){
                    badgeIds = new Set<Id>{trailmixBadge.Badge__c};
                }else{
                    badgeIds.add(trailmixBadge.Badge__c);
                }
                trailmixBadgeMap.put(trailmixBadge.Trailmix__c, badgeIds);
            }
            System.debug('trailmixBadges: ' +trailmixBadges);
            return trailmixBadgeMap;
        }                           
    }

    /**
     * Return a map of User Badge records that for a list of users
     * userIds: the set of User Ids
     */
    private static Map<Id, Set<Id>> constructUserBadgeRealityMap(Set<Id> userIds){
        List<trailheadapp__User_Badge__c> userBadgeReality = [SELECT Id, trailheadapp__User__c, trailheadapp__Badge__c 
                                                              FROM trailheadapp__User_Badge__c
                                                              WHERE trailheadapp__User__c in : userIds];
        System.debug('userBadgeReality: ' + userBadgeReality);
        Map<Id, Set<Id>> userBadgeRealityMap = new Map<Id, Set<Id>>();
        for(trailheadapp__User_Badge__c userBadge : userBadgeReality){
            Set<Id> badgeIds = userBadgeRealityMap.get(userBadge.trailheadapp__User__c);
            if(badgeIds == null){
                badgeIds = new Set<Id>{userBadge.trailheadapp__Badge__c};
            }else{
                badgeIds.add(userBadge.trailheadapp__Badge__c);
            }
            userBadgeRealityMap.put(userBadge.trailheadapp__User__c, badgeIds);
        }
        System.debug('userBadgeReality: ' + userBadgeReality);
        System.debug('userBadgeRealityMap: ' + userBadgeRealityMap);
        return userBadgeRealityMap;
    }

    /**
     * Return a list of User Badge records that need to be created for all users
     * trailmixBadgeMap: the map of badges (value) belongs to a trailmix (key)
     * userBadgeRealityMap: the map of badges (value) assigned to each user (key)
     * trailmixIds: the set of Trailmix Ids
     * userIds: the set of User Ids
     */
    private static List<trailheadapp__User_Badge__c> createUserBadge(Map<Id, Set<Id>> trailmixBadgeMap, Map<Id, Set<Id>> userBadgeRealityMap, Set<Id> trailmixIds, Set<Id> userIds){
        List<trailheadapp__User_Badge__c> userBadgesToCreate = new List<trailheadapp__User_Badge__c>();
        for(Id userId : userIds){
            for(Id trailmixId : trailmixIds){
                userBadgesToCreate.addAll(compareRealityVsExpected(trailmixBadgeMap.get(trailmixId),userBadgeRealityMap.get(userId), userId));
            }
        }
        System.debug('userBadgesToCreate: ' + userBadgesToCreate);
        System.debug('userBadgesToCreate size: ' + userBadgesToCreate.size());
        return userBadgesToCreate;
    }

    /**
     * Return a list of User Badge records that need to be created for a specific user
     * badgeExpected: the set of badges that the user should to be assigned
     * badgeReality: the set of badges that the user is assigned 
     * userId: the User's Id
     */
    private static List<trailheadapp__User_Badge__c> compareRealityVsExpected(Set<Id> badgeExpected, Set<Id> badgeReality, Id userId){
        List<trailheadapp__User_Badge__c> userBadgesToCreate = new List<trailheadapp__User_Badge__c>();
        for(Id badgeId : badgeExpected){
            if(!badgeReality.contains(badgeId)){
                userBadgesToCreate.add(new trailheadapp__User_Badge__c(trailheadapp__Status__c = 'Assigned', trailheadapp__User__c = userId, trailheadapp__Badge__c = badgeId));
            }
        }
        return userBadgesToCreate;
    }
}