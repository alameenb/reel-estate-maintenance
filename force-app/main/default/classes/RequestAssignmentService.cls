/**
 * CMP-085. Maintains Request_Assignment__c periods (who/which team held a request
 * and for how long). Periods are system audit data that users must not edit, so this
 * class runs without sharing and is called only from CaseTriggerHandler.
 * Documented exception to the with-sharing default (design: inherited sharing + SYSTEM_MODE).
 */
public without sharing class RequestAssignmentService {
    private static Boolean isUser(Id ownerId) { return ownerId != null && String.valueOf(ownerId).startsWith('005'); }

    public static void onAfterInsert(List<Case> newCases) {
        List<Request_Assignment__c> periods = new List<Request_Assignment__c>();
        for (Case c : newCases) {
            if (!MaintenanceConstants.isMaintenance(c)) { continue; }
            Datetime start = c.CreatedDate == null ? Datetime.now() : c.CreatedDate;
            if (isUser(c.OwnerId)) { periods.add(rep(c.Id, c.OwnerId, start)); }
            if (String.isNotBlank(c.Maintenance_Team__c)) { periods.add(team(c.Id, c.Maintenance_Team__c, start)); }
        }
        if (!periods.isEmpty()) { insert periods; }
    }

    public static void onAfterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        Set<Id> ownerChanged = new Set<Id>(), teamChanged = new Set<Id>(), closed = new Set<Id>();
        Map<Id, Case> byId = new Map<Id, Case>();
        for (Case c : newCases) {
            if (!MaintenanceConstants.isMaintenance(c)) { continue; }
            Case o = oldMap.get(c.Id);
            byId.put(c.Id, c);
            if (c.IsClosed && !o.IsClosed) { closed.add(c.Id); continue; }
            if (c.OwnerId != o.OwnerId) { ownerChanged.add(c.Id); }
            if (c.Maintenance_Team__c != o.Maintenance_Team__c) { teamChanged.add(c.Id); }
        }
        Set<Id> all = new Set<Id>(); all.addAll(ownerChanged); all.addAll(teamChanged); all.addAll(closed);
        if (all.isEmpty()) { return; }

        Datetime nowTs = Datetime.now();
        List<Request_Assignment__c> toUpdate = new List<Request_Assignment__c>();
        for (Request_Assignment__c p : [SELECT Id, Case__c, Assignment_Type__c FROM Request_Assignment__c WHERE Case__c IN :all AND End__c = NULL]) {
            Boolean isRep = p.Assignment_Type__c == 'Representative';
            if (closed.contains(p.Case__c)) {
                Datetime cd = byId.get(p.Case__c).ClosedDate;
                p.End__c = cd == null ? nowTs : cd;
                toUpdate.add(p);
            } else if ((isRep && ownerChanged.contains(p.Case__c)) || (!isRep && teamChanged.contains(p.Case__c))) {
                p.End__c = nowTs;
                toUpdate.add(p);
            }
        }
        List<Request_Assignment__c> toInsert = new List<Request_Assignment__c>();
        for (Id cid : ownerChanged) { if (isUser(byId.get(cid).OwnerId)) { toInsert.add(rep(cid, byId.get(cid).OwnerId, nowTs)); } }
        for (Id cid : teamChanged) { if (String.isNotBlank(byId.get(cid).Maintenance_Team__c)) { toInsert.add(team(cid, byId.get(cid).Maintenance_Team__c, nowTs)); } }
        if (!toUpdate.isEmpty()) { update toUpdate; }
        if (!toInsert.isEmpty()) { insert toInsert; }
    }

    private static Request_Assignment__c rep(Id caseId, Id userId, Datetime start) {
        return new Request_Assignment__c(Case__c = caseId, Assignment_Type__c = 'Representative', Assignee_User__c = userId, Start__c = start);
    }
    private static Request_Assignment__c team(Id caseId, String teamName, Datetime start) {
        return new Request_Assignment__c(Case__c = caseId, Assignment_Type__c = 'Team', Team__c = teamName, Start__c = start);
    }
}
