// Verifies rule-based record access on real records (complements the Apex tests, because this org
// calculates criteria-based sharing asynchronously). Throws on any mismatch. Run after deploy + demo data.
String suffix = '@reelestate.' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
Map<String, Id> u = new Map<String, Id>();
for (User x : [SELECT Id, Username FROM User WHERE Username LIKE :('%' + suffix)]) u.put(x.Username.substringBefore('@'), x.Id);
List<Case> cs = [SELECT Id, CaseNumber, OwnerId, Maintenance_Team__c, ContactId, Contact.Email FROM Case WHERE RecordType.DeveloperName = 'Maintenance_Request'];
Map<Id, Id> portalByContact = new Map<Id, Id>();
for (User p : [SELECT Id, ContactId FROM User WHERE ContactId != null AND IsActive = true]) portalByContact.put(p.ContactId, p.Id);
List<String> failures = new List<String>(); Integer checks = 0;
Set<Id> caseIds = new Map<Id, Case>(cs).keySet();
Map<String, UserRecordAccess> access = new Map<String, UserRecordAccess>();
List<Id> who = new List<Id>{ u.get('chloe'), u.get('marcus') };
who.addAll(portalByContact.values());
for (Id w : who) {
    for (UserRecordAccess a : [SELECT RecordId, HasReadAccess, HasEditAccess FROM UserRecordAccess WHERE UserId = :w AND RecordId IN :caseIds]) access.put(w + ':' + a.RecordId, a);
}
for (Case c : cs) {
    // Chloe (CSR): edit only what she owns
    Boolean chloeEdit = access.get(u.get('chloe') + ':' + c.Id).HasEditAccess; checks++;
    if (chloeEdit != (c.OwnerId == u.get('chloe'))) failures.add(c.CaseNumber + ': CSR edit=' + chloeEdit + ' but owner check=' + (c.OwnerId == u.get('chloe')));
    // Marcus (Supervisors & Managers group + Plumbing team): read/write on every maintenance request
    checks++; if (!access.get(u.get('marcus') + ':' + c.Id).HasEditAccess) failures.add(c.CaseNumber + ': manager has no edit access');
    // Portal customers: their own requests only
    for (Id contactId : portalByContact.keySet()) {
        Boolean own = c.ContactId == contactId, read = access.get(portalByContact.get(contactId) + ':' + c.Id).HasReadAccess; checks++;
        if (read != own) failures.add(c.CaseNumber + ': portal user of contact ' + contactId + ' read=' + read + ' own=' + own);
    }
}
System.debug('VERIFY checks=' + checks + ' failures=' + failures.size() + ' ' + String.join(failures, ' | '));
if (!failures.isEmpty()) throw new HandledException(String.join(failures, '\n'));
