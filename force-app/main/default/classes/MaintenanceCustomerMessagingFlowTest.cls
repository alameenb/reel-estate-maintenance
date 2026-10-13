@IsTest
private class MaintenanceCustomerMessagingFlowTest {
    private static User csr() { return TestDataFactory.createInternalUser(new List<String>{ 'Maintenance_CSR', 'Maintenance_Resolution_Confirmation' }, null, null); }
    private static Case ownedCase(User owner, Id contactId) {
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', contactId, false);
        cs[0].OwnerId = owner.Id;
        insert cs;
        return cs[0];
    }

    @IsTest static void informationRequestPostsCustomerVisibleMessage() {
        User u = csr();
        Case c = ownedCase(u, TestDataFactory.createAccountWithContact(true).Id);
        MaintenanceMessaging.emailsQueued = 0;
        System.runAs(u) {
            Flow.Interview.Maintenance_Request_Information_Action fi = new Flow.Interview.Maintenance_Request_Information_Action(
                new Map<String, Object>{ 'recordId' => c.Id, 'informationRequest' => 'Please send a photo of the leak' });
            fi.start();
            Assert.areEqual(true, fi.getVariableValue('success'), '' + fi.getVariableValue('errorMessage'));
        }
        FeedItem f = [SELECT Body, Visibility FROM FeedItem WHERE ParentId = :c.Id AND Type = 'TextPost' LIMIT 1];
        Assert.areEqual('AllUsers', f.Visibility);
        Assert.isTrue(f.Body.contains('photo of the leak'));
        Assert.areEqual(1, MaintenanceMessaging.emailsQueued, 'Customer emailed through the feed trigger');
    }

    @IsTest static void confirmResolutionSetsResolvedAndLogsInternalPost() {
        User u = csr();
        Case c = ownedCase(u, TestDataFactory.createAccountWithContact(true).Id);
        System.runAs(u) {
            Flow.Interview.Maintenance_Confirm_Resolution_Action fi = new Flow.Interview.Maintenance_Confirm_Resolution_Action(new Map<String, Object>{ 'recordId' => c.Id });
            fi.start();
            Assert.areEqual(true, fi.getVariableValue('success'), '' + fi.getVariableValue('errorMessage'));
        }
        Assert.areEqual('Resolved', [SELECT Status FROM Case WHERE Id = :c.Id].Status);
        Assert.areEqual(1, [SELECT COUNT() FROM FeedItem WHERE ParentId = :c.Id AND Visibility = 'InternalUsers' AND Type = 'TextPost']);
    }

    @IsTest static void closedOrNoContactReturnsError() {
        User u = csr();
        Case noContact = ownedCase(u, null);
        System.runAs(u) {
            Flow.Interview.Maintenance_Confirm_Resolution_Action fi = new Flow.Interview.Maintenance_Confirm_Resolution_Action(new Map<String, Object>{ 'recordId' => noContact.Id });
            fi.start();
            Assert.areEqual(false, fi.getVariableValue('success'));
            Assert.isNotNull(fi.getVariableValue('errorMessage'));
        }
        Assert.areEqual('New', [SELECT Status FROM Case WHERE Id = :noContact.Id].Status);
    }

    @IsTest static void otherCsrCannotResolve() {
        User owner = csr(); User other = csr();
        Case c = ownedCase(owner, TestDataFactory.createAccountWithContact(true).Id);
        System.runAs(other) {
            Flow.Interview.Maintenance_Confirm_Resolution_Action fi = new Flow.Interview.Maintenance_Confirm_Resolution_Action(new Map<String, Object>{ 'recordId' => c.Id });
            fi.start();
            Assert.areEqual(false, fi.getVariableValue('success'));
        }
        Assert.areEqual('New', [SELECT Status FROM Case WHERE Id = :c.Id].Status);
    }
}
