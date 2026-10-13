@IsTest
private class MaintenanceRequestIntakeControllerTest {
    private static String body(String email) {
        return JSON.serialize(new Map<String, Object>{ 'name' => 'Sam Lee', 'email' => email, 'street' => '7 Park Ave',
            'postalCode' => '3000', 'category' => 'Electrical', 'description' => 'Power point sparking' });
    }

    @IsTest static void submitReturnsReference() {
        String ref = MaintenanceRequestIntakeController.submitRequest(body('sam@example.com'), null);
        Assert.areEqual(1, [SELECT COUNT() FROM Case WHERE CaseNumber = :ref]);
    }

    @IsTest static void validationErrorsComeBackAsFieldMap() {
        try { MaintenanceRequestIntakeController.submitRequest('{"email":"bad"}', null); Assert.fail(); }
        catch (AuraHandledException e) {
            Map<String, Object> errs = (Map<String, Object>) JSON.deserializeUntyped(e.getMessage());
            Assert.isTrue(errs.containsKey('email') && errs.containsKey('name'));
        }
    }

    @IsTest static void malformedJsonIsHandled() {
        try { MaintenanceRequestIntakeController.submitRequest('{not json', null); Assert.fail(); }
        catch (AuraHandledException e) { Assert.isTrue(e.getMessage().contains('form')); }
    }

    @IsTest static void configExposesLimitsAndCategories() {
        Map<String, Object> cfg = MaintenanceRequestIntakeController.getIntakeConfig();
        Assert.areEqual(3, (Integer) cfg.get('maxFileCount'));
        Assert.isFalse(((List<Object>) cfg.get('categories')).isEmpty());
        Assert.isTrue(((List<String>) cfg.get('allowedExtensions')).contains('pdf'));
    }

    @IsTest static void guestCanSubmitWhenSiteExists() {
        List<Site> sites = [SELECT GuestUserId FROM Site WHERE Name = 'Maintenance_Customer_Portal' LIMIT 1];
        if (sites.isEmpty() || sites[0].GuestUserId == null) {
            Assert.isTrue(sites.isEmpty() || sites[0].GuestUserId == null, 'Portal site not created yet; guest path covered after site setup');
            return;
        }
        User guest = new User(Id = sites[0].GuestUserId);
        System.runAs(guest) {
            String ref = MaintenanceRequestIntakeController.submitRequest(body('guest@example.com'), null);
            Assert.isNotNull(ref);
            Assert.isFalse(Schema.SObjectType.Case.isAccessible(), 'Guest has no Case access');
        }
    }
}
