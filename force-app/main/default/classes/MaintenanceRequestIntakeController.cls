/** CMP-048. The only Apex class exposed to the site guest user. */
public with sharing class MaintenanceRequestIntakeController {
    @AuraEnabled
    public static String submitRequest(String requestJson, String filesJson) {
        MaintenanceRequestIntakeService.IntakeRequest req;
        List<MaintenanceRequestIntakeService.FileInput> files;
        try {
            req = (MaintenanceRequestIntakeService.IntakeRequest) JSON.deserialize(
                String.isBlank(requestJson) ? '{}' : requestJson, MaintenanceRequestIntakeService.IntakeRequest.class);
            files = String.isBlank(filesJson) ? new List<MaintenanceRequestIntakeService.FileInput>()
                : (List<MaintenanceRequestIntakeService.FileInput>) JSON.deserialize(filesJson, List<MaintenanceRequestIntakeService.FileInput>.class);
        } catch (Exception e) {
            throw fail(new Map<String, String>{ 'form' => 'The form data could not be read. Please try again.' });
        }
        trim(req);
        try {
            return MaintenanceRequestIntakeService.submit(req, files);
        } catch (MaintenanceRequestIntakeService.IntakeValidationException v) {
            throw fail(v.fieldErrors);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Intake failed: ' + e.getMessage());
            throw fail(new Map<String, String>{ 'form' => 'We could not submit your request right now. Please try again later.' });
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getIntakeConfig() {
        Request_Setting__mdt s = MaintenanceConstants.settings();
        List<Map<String, String>> categories = new List<Map<String, String>>();
        for (Schema.PicklistEntry e : Case.Issue_Category__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) { categories.add(new Map<String, String>{ 'label' => e.getLabel(), 'value' => e.getValue() }); }
        }
        return new Map<String, Object>{
            'allowedExtensions' => MaintenanceRequestIntakeService.allowedExtensions(),
            'maxFileSizeKb' => s.Max_File_Size_KB__c == null ? 1024 : s.Max_File_Size_KB__c.intValue(),
            'maxFileCount' => s.Max_File_Count__c == null ? 3 : s.Max_File_Count__c.intValue(),
            'categories' => categories,
            'mandatoryFields' => new List<String>(MaintenanceRequestIntakeService.MANDATORY)
        };
    }

    private static void trim(MaintenanceRequestIntakeService.IntakeRequest r) {
        if (r == null) { return; }
        r.name = clip(r.name, 120); r.email = clip(r.email, 80); r.phone = clip(r.phone, 40);
        r.street = clip(r.street, 255); r.city = clip(r.city, 80); r.postalCode = clip(r.postalCode, 20);
        r.category = clip(r.category, 80); r.description = clip(r.description, 32000);
    }
    private static String clip(String s, Integer n) { return s == null ? null : s.trim().left(n); }

    private static AuraHandledException fail(Map<String, String> errors) {
        String body = JSON.serialize(errors);
        AuraHandledException e = new AuraHandledException(body);
        e.setMessage(body);
        return e;
    }
}
