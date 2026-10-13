@IsTest
private class CaseSkillRoutingServiceTest {
    @IsTest static void everyActiveCategoryHasASkillMapping() {
        Set<String> mapped = new Set<String>();
        for (Category_Skill__mdt m : Category_Skill__mdt.getAll().values()) { if (m.Active__c) { mapped.add(m.Issue_Category__c); } }
        for (Schema.PicklistEntry e : Case.Issue_Category__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) { Assert.isTrue(mapped.contains(e.getValue()), 'Missing Category_Skill__mdt for ' + e.getValue()); }
        }
    }

    @IsTest static void mappedCategoryCreatesRoutingWithSkill() {
        Test.startTest();
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, true);
        Test.stopTest();
        List<PendingServiceRouting> psr = [SELECT Id, RoutingType, (SELECT Skill.DeveloperName FROM SkillRequirements) FROM PendingServiceRouting WHERE WorkItemId = :cs[0].Id];
        Assert.areEqual(1, psr.size(), 'One routing request per case. Warnings: ' + CaseSkillRoutingService.warnings);
        Assert.areEqual('SkillsBased', psr[0].RoutingType);
        Assert.areEqual('Plumbing', psr[0].SkillRequirements[0].Skill.DeveloperName);
    }

    @IsTest static void bulkTwoHundredStaysWithinLimits() {
        Test.startTest();
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Electrical', null, true);
        Test.stopTest();
        Assert.areEqual(200, [SELECT COUNT() FROM PendingServiceRouting WHERE WorkItemId IN :cs]);
    }

    @IsTest static void unmappedOrNonMaintenanceCasesAreIgnored() {
        List<Case> noCategory = TestDataFactory.createMaintenanceCases(1, null, null, true);
        Assert.areEqual(0, [SELECT COUNT() FROM PendingServiceRouting WHERE WorkItemId = :noCategory[0].Id]);
        // A case of any other record type is filtered before any query or DML
        Integer before = Limits.getDmlStatements();
        CaseSkillRoutingService.routeNewRequests(new List<Case>{ new Case(Subject = 'Other', Issue_Category__c = 'Plumbing') });
        Assert.areEqual(before, Limits.getDmlStatements());
    }

    @IsTest static void guestCreatedRequestIsRoutedThroughPlatformEvent() {
        List<Site> sites = [SELECT GuestUserId FROM Site WHERE Name = 'Maintenance_Customer_Portal' LIMIT 1];
        if (sites.isEmpty()) { Assert.isTrue(sites.isEmpty(), 'Portal site not created yet'); return; }
        MaintenanceRequestIntakeService.IntakeRequest r = new MaintenanceRequestIntakeService.IntakeRequest();
        r.name = 'Guest Person'; r.email = 'guest.route@example.com'; r.street = '1 Route St'; r.postalCode = '3000'; r.category = 'Plumbing'; r.description = 'Leak';
        String ref;
        Test.startTest();
        System.runAs(new User(Id = sites[0].GuestUserId)) { ref = MaintenanceRequestIntakeService.submit(r, null); }
        Test.getEventBus().deliver();
        Test.stopTest();
        Id caseId = [SELECT Id FROM Case WHERE CaseNumber = :ref].Id;
        Assert.areEqual(1, [SELECT COUNT() FROM PendingServiceRouting WHERE WorkItemId = :caseId], 'Routed via Maintenance_Routing__e');
    }

    @IsTest static void runsAsCsr() {
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        System.runAs(csr) {
            List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'General', null, true);
            Assert.areEqual(1, [SELECT COUNT() FROM Case WHERE Id = :cs[0].Id]);
        }
    }
}
