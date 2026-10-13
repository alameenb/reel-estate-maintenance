/**
 * CMP-006. Routes new Maintenance Request cases to CSRs through Omni-Channel
 * skills-based routing: one PendingServiceRouting per case plus a SkillRequirement
 * for the category's skill (Category_Skill__mdt). Unmapped categories stay unrouted.
 */
public with sharing class CaseSkillRoutingService {
    @TestVisible private static List<String> warnings = new List<String>();

    public static void routeNewRequests(List<Case> cases) {
        List<Case> eligible = new List<Case>();
        for (Case c : cases) {
            if (MaintenanceConstants.isMaintenance(c) && String.isNotBlank(c.Issue_Category__c)) { eligible.add(c); }
        }
        if (eligible.isEmpty()) { return; }
        // Guest and portal licences cannot access Omni-Channel objects, so hand off to the
        // Maintenance_Routing__e trigger, which runs as the Automated Process user.
        if (UserInfo.getUserType() != 'Standard' && UserInfo.getUserType() != 'AutomatedProcess') {
            List<Maintenance_Routing__e> events = new List<Maintenance_Routing__e>();
            for (Case c : eligible) { events.add(new Maintenance_Routing__e(Case_Id__c = c.Id)); }
            EventBus.publish(events);
            return;
        }

        Map<String, Category_Skill__mdt> byCategory = new Map<String, Category_Skill__mdt>();
        for (Category_Skill__mdt m : Category_Skill__mdt.getAll().values()) {
            if (m.Active__c) { byCategory.put(m.Issue_Category__c, m); }
        }
        Set<String> skillNames = new Set<String>();
        for (Category_Skill__mdt m : byCategory.values()) { skillNames.add(m.Skill_Developer_Name__c); }
        Map<String, Id> skillIds = new Map<String, Id>();
        for (Skill s : [SELECT Id, DeveloperName FROM Skill WHERE DeveloperName IN :skillNames]) { skillIds.put(s.DeveloperName, s.Id); }
        List<ServiceChannel> channels = [SELECT Id FROM ServiceChannel WHERE DeveloperName = :MaintenanceConstants.SERVICE_CHANNEL LIMIT 1];
        if (channels.isEmpty()) {
            warnings.add('Service channel ' + MaintenanceConstants.SERVICE_CHANNEL + ' not found; requests left unrouted.');
            System.debug(LoggingLevel.WARN, warnings[warnings.size() - 1]);
            return;
        }

        List<PendingServiceRouting> psrs = new List<PendingServiceRouting>();
        Map<Id, Id> skillByCase = new Map<Id, Id>();
        Map<Id, Integer> levelByCase = new Map<Id, Integer>();
        for (Case c : eligible) {
            Category_Skill__mdt map1 = byCategory.get(c.Issue_Category__c);
            Id skillId = map1 == null ? null : skillIds.get(map1.Skill_Developer_Name__c);
            if (skillId == null) {
                warnings.add('No active skill mapping for category ' + c.Issue_Category__c + ' on case ' + c.Id);
                System.debug(LoggingLevel.WARN, warnings[warnings.size() - 1]);
                continue;
            }
            skillByCase.put(c.Id, skillId);
            levelByCase.put(c.Id, map1.Skill_Level__c == null ? 1 : map1.Skill_Level__c.intValue());
            psrs.add(new PendingServiceRouting(
                WorkItemId = c.Id, ServiceChannelId = channels[0].Id, RoutingType = 'SkillsBased',
                RoutingModel = 'MostAvailable', RoutingPriority = 1, CapacityWeight = 1, IsReadyForRouting = false));
        }
        if (psrs.isEmpty()) { return; }
        try {
            insert psrs;
            List<SkillRequirement> reqs = new List<SkillRequirement>();
            for (PendingServiceRouting p : psrs) {
                reqs.add(new SkillRequirement(RelatedRecordId = p.Id, SkillId = skillByCase.get(p.WorkItemId), SkillLevel = levelByCase.get(p.WorkItemId)));
            }
            insert reqs;
            for (PendingServiceRouting p : psrs) { p.IsReadyForRouting = true; }
            update psrs;
        } catch (DmlException e) {
            // Routing must never block request creation; the case stays in the intake queue.
            warnings.add('Routing failed: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, warnings[warnings.size() - 1]);
        }
    }
}
