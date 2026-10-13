/** Routes requests created by guest or portal users (runs as the Automated Process user). */
trigger MaintenanceRoutingTrigger on Maintenance_Routing__e (after insert) {
    Set<Id> ids = new Set<Id>();
    for (Maintenance_Routing__e e : Trigger.new) { ids.add(e.Case_Id__c); }
    CaseSkillRoutingService.routeNewRequests([SELECT Id, RecordTypeId, Issue_Category__c FROM Case WHERE Id IN :ids]);
}
