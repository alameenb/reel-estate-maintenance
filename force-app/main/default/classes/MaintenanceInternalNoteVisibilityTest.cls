@IsTest
private class MaintenanceInternalNoteVisibilityTest {
    @IsTest static void internalNotesHiddenFromCustomerAndNotEmailed() {
        Map<String, SObject> pc = TestDataFactory.createPortalCustomer(new List<String>{ 'Maintenance_Portal_Customer' });
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        Id contactId = pc == null ? TestDataFactory.createAccountWithContact(true).Id : pc.get('contact').Id;
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', contactId, false);
        cs[0].OwnerId = csr.Id;
        insert cs;
        MaintenanceMessaging.emailsQueued = 0;
        System.runAs(csr) {
            insert new FeedItem(ParentId = cs[0].Id, Body = 'Internal: customer is difficult', Visibility = 'InternalUsers', Type = 'TextPost');
            insert new FeedItem(ParentId = cs[0].Id, Body = 'We will be there Tuesday', Visibility = 'AllUsers', Type = 'TextPost');
            Assert.areEqual(2, [SELECT COUNT() FROM CaseFeed WHERE ParentId = :cs[0].Id AND Type = 'TextPost']);
        }
        Assert.areEqual(1, MaintenanceMessaging.emailsQueued, 'Only the customer-visible post emails the customer. ' + String.join(MaintenanceMessaging.log, '; '));
        if (pc != null) {
            System.runAs((User) pc.get('user')) {
                List<CaseFeed> seen = [SELECT Body FROM CaseFeed WHERE ParentId = :cs[0].Id AND Type = 'TextPost' WITH USER_MODE];
                Assert.areEqual(1, seen.size());
                Assert.isTrue(seen[0].Body.contains('Tuesday'));
            }
        }
    }

    @IsTest static void bulkInternalNotesSendNothing() {
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', c.Id, false);
        for (Case x : cs) { x.OwnerId = csr.Id; }
        insert cs;
        MaintenanceMessaging.emailsQueued = 0;
        List<FeedItem> notes = new List<FeedItem>();
        for (Case x : cs) { notes.add(new FeedItem(ParentId = x.Id, Body = 'note', Visibility = 'InternalUsers', Type = 'TextPost')); }
        System.runAs(csr) { insert notes; }
        Assert.areEqual(0, MaintenanceMessaging.emailsQueued);
    }
}
