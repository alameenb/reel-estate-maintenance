/**
 * CMP-049. Invocable dispatcher called by the Maintenance_Request_Notifications flow.
 * Rules live in Notification_Rule__mdt, so changing who is told what needs no deployment
 * (REQ-029). A rule with a specific Status__c takes precedence over the generic rule for
 * the same event, so the customer receives one message, not two.
 */
public with sharing class MaintenanceNotificationService {
    public class Request {
        @InvocableVariable(label='Case Id' required=true) public Id caseId;
        @InvocableVariable(label='Event (Submitted, Status_Changed, Appointment_Set)' required=true) public String eventName;
    }

    @TestVisible private static List<Notification_Rule__mdt> rulesOverride;

    private static List<Notification_Rule__mdt> activeRules() {
        List<Notification_Rule__mdt> source = rulesOverride != null ? rulesOverride : Notification_Rule__mdt.getAll().values();
        List<Notification_Rule__mdt> active = new List<Notification_Rule__mdt>();
        for (Notification_Rule__mdt r : source) { if (r.Active__c) { active.add(r); } }
        return active;
    }

    @InvocableMethod(label='Send Maintenance Notifications' description='Sends customer email and portal notifications according to Notification_Rule__mdt.')
    public static void sendNotifications(List<Request> requests) {
        if (requests == null || requests.isEmpty()) { return; }
        Map<Id, Set<String>> events = new Map<Id, Set<String>>();
        for (Request r : requests) {
            if (r == null || r.caseId == null || String.isBlank(r.eventName)) { continue; }
            if (!events.containsKey(r.caseId)) { events.put(r.caseId, new Set<String>()); }
            events.get(r.caseId).add(r.eventName);
        }
        if (events.isEmpty()) { return; }
        List<Notification_Rule__mdt> rules = activeRules();
        Map<Id, Case> cases = MaintenanceMessaging.casesForMessaging(events.keySet());
        Set<Id> contactIds = new Set<Id>();
        for (Case c : cases.values()) { if (c.ContactId != null) { contactIds.add(c.ContactId); } }
        Map<Id, Id> portalUser = MaintenanceMessaging.portalUsersByContact(contactIds);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Id caseId : events.keySet()) {
            Case c = cases.get(caseId);
            if (c == null || c.ContactId == null) { continue; }
            for (String ev : events.get(caseId)) {
                for (Notification_Rule__mdt rule : matching(rules, ev, c.Status)) {
                    if (String.isNotBlank(c.Contact.Email)) {
                        emails.add(MaintenanceMessaging.buildEmail(rule.Email_Template__c, c, null, rule.Sender_Address__c));
                    }
                    if (portalUser.containsKey(c.ContactId)) {
                        String title = (String.isBlank(rule.Notification_Title__c) ? 'Update' : rule.Notification_Title__c) + ' - request ' + c.CaseNumber;
                        MaintenanceMessaging.notify(rule.Notification_Type__c, title, 'Status: ' + c.Status, c.Id, new Set<String>{ portalUser.get(c.ContactId) });
                    }
                }
            }
        }
        MaintenanceMessaging.send(emails);
    }

    @TestVisible
    private static List<Notification_Rule__mdt> matching(List<Notification_Rule__mdt> rules, String eventName, String status) {
        List<Notification_Rule__mdt> specific = new List<Notification_Rule__mdt>(), generic = new List<Notification_Rule__mdt>();
        for (Notification_Rule__mdt r : rules) {
            if (r.Event__c != eventName) { continue; }
            if (String.isNotBlank(r.Status__c)) {
                if (r.Status__c == status) { specific.add(r); }
            } else {
                Set<String> excluded = new Set<String>();
                if (String.isNotBlank(r.Excluded_Statuses__c)) {
                    for (String s : r.Excluded_Statuses__c.split(',')) { excluded.add(s.trim()); }
                }
                if (!excluded.contains(status)) { generic.add(r); }
            }
        }
        return specific.isEmpty() ? generic : specific;
    }
}
