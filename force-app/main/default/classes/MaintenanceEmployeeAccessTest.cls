/**
 * CMP-130. Employee edit access. Ownership isolation and permission-set limits are asserted here.
 * Team and supervisor access come from criteria-based sharing rules (CMP-067, CMP-127), which this
 * org calculates asynchronously, so those are verified against real records by
 * scripts/apex/verify-sharing.apex (run after deployment; it fails loudly on any mismatch).
 */
@IsTest
private class MaintenanceEmployeeAccessTest {
    private static Boolean canEdit(Id userId, Id recordId) {
        return [SELECT RecordId, HasEditAccess FROM UserRecordAccess WHERE UserId = :userId AND RecordId = :recordId].HasEditAccess;
    }

    @IsTest static void csrsEditOnlyTheirOwnRequests() {
        User csr1 = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        User csr2 = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', null, false);
        for (Integer i = 0; i < cs.size(); i++) { cs[i].OwnerId = Math.mod(i, 2) == 0 ? csr1.Id : csr2.Id; }
        insert cs;
        Assert.isTrue(canEdit(csr1.Id, cs[0].Id));
        Assert.isFalse(canEdit(csr1.Id, cs[1].Id), 'CSR cannot edit another CSR\'s request');
        System.runAs(csr1) { Assert.areEqual(100, [SELECT COUNT() FROM Case WHERE Id IN :cs WITH USER_MODE]); }
    }

    @IsTest static void teamMemberPermissions() {
        User teamA = TestDataFactory.createUserWithPermissionSet('Maintenance_Team_Member', null);
        System.runAs(teamA) {
            Assert.isTrue(Schema.SObjectType.Case.isUpdateable());
            Assert.isFalse(Schema.SObjectType.Case.isCreateable(), 'Team members do not create requests');
            Assert.isTrue(Schema.SObjectType.Case.fields.Appointment_DateTime__c.isUpdateable());
            Assert.isFalse(Schema.SObjectType.Case.fields.Is_Escalated__c.isUpdateable());
        }
    }

    @IsTest static void teamAndSupervisorGroupsExist() {
        Set<String> names = new Set<String>();
        for (Group g : [SELECT DeveloperName FROM Group WHERE DeveloperName LIKE 'Maintenance_%' AND Type = 'Regular']) { names.add(g.DeveloperName); }
        Assert.isTrue(names.contains('Maintenance_Supervisors_Managers'));
        for (Schema.PicklistEntry e : Case.Maintenance_Team__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) { Assert.isTrue(names.contains('Maintenance_Team_' + e.getValue()), 'Missing group for team ' + e.getValue()); }
        }
    }
}
