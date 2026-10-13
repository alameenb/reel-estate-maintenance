/**
 * Shared names for the maintenance request solution. Everything is resolved by
 * DeveloperName at runtime; no record Ids are hardcoded anywhere.
 */
public inherited sharing class MaintenanceConstants {
    public static final String RECORD_TYPE = 'Maintenance_Request';
    public static final String STATUS_NEW = 'New';
    public static final String STATUS_AWAITING_INFO = 'Awaiting Customer Information';
    public static final String STATUS_RESOLVED = 'Resolved';
    public static final String STATUS_CLOSED = 'Closed';
    public static final String ESCALATION_QUEUE = 'Maintenance_Escalation';
    public static final String INTAKE_QUEUE = 'Maintenance_Requests';
    public static final String SERVICE_CHANNEL = 'Maintenance_Request_Case';
    public static final String NOTIFICATION_TYPE = 'Maintenance_Request_Message';
    public static final String CUSTOMER_MESSAGE_TEMPLATE = 'Maintenance_Customer_Message';

    private static Id recordTypeIdCache;
    public static Id recordTypeId() {
        if (recordTypeIdCache == null) {
            Schema.RecordTypeInfo info = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(RECORD_TYPE);
            recordTypeIdCache = info == null ? null : info.getRecordTypeId();
        }
        return recordTypeIdCache;
    }

    public static Request_Setting__mdt settings() {
        Request_Setting__mdt s = Request_Setting__mdt.getInstance('Default');
        return s == null ? new Request_Setting__mdt(Escalation_Days__c = 5, Auto_Close_Days__c = 42) : s;
    }

    public static Boolean isMaintenance(Case c) {
        return c != null && c.RecordTypeId != null && c.RecordTypeId == recordTypeId();
    }
}
