// Step 1 of 2: presence status access for the CSR permission set (setup object, separate transaction).
Id status = [SELECT Id FROM ServicePresenceStatus WHERE DeveloperName = 'Available_Maintenance_Requests'].Id;
for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN ('Maintenance_CSR')]) {
    if ([SELECT COUNT() FROM SetupEntityAccess WHERE ParentId = :ps.Id AND SetupEntityId = :status] == 0) insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = status);
}
System.debug('OMNI_OK status access');
