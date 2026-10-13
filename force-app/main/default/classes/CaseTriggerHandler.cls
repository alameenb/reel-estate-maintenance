/** CMP-007. Single handler for CaseTrigger. */
public with sharing class CaseTriggerHandler {
    @TestVisible private static Set<Id> routed = new Set<Id>();
    @TestVisible private static Integer routingRuns = 0;

    public void afterInsert(List<Case> newList) {
        RequestAssignmentService.onAfterInsert(newList);
        List<Case> toRoute = new List<Case>();
        for (Case c : newList) { if (!routed.contains(c.Id)) { routed.add(c.Id); toRoute.add(c); } }
        if (!toRoute.isEmpty()) { routingRuns++; CaseSkillRoutingService.routeNewRequests(toRoute); }
    }

    public void afterUpdate(List<Case> newList, Map<Id, Case> oldMap) {
        RequestAssignmentService.onAfterUpdate(newList, oldMap);
    }
}
