// Step 2 of 2: Omni-Channel agent and skills for the demo CSR: presence configuration, presence status access, agent skills.
String suffix = '@reelestate.' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
User chloe = [SELECT Id FROM User WHERE Username = :('chloe' + suffix)];
Id csrPs = [SELECT Id FROM PermissionSet WHERE Name = 'Maintenance_CSR'].Id;
List<ServiceResource> sr = [SELECT Id FROM ServiceResource WHERE RelatedRecordId = :chloe.Id];
ServiceResource r = sr.isEmpty() ? new ServiceResource(Name = 'Chloe Nguyen', RelatedRecordId = chloe.Id, ResourceType = 'A', IsActive = true) : sr[0];
if (sr.isEmpty()) insert r;
Set<Id> have = new Set<Id>();
for (ServiceResourceSkill s : [SELECT SkillId FROM ServiceResourceSkill WHERE ServiceResourceId = :r.Id]) have.add(s.SkillId);
List<ServiceResourceSkill> add = new List<ServiceResourceSkill>();
for (Skill s : [SELECT Id FROM Skill WHERE DeveloperName IN ('Plumbing', 'Electrical', 'General', 'Appliances', 'Heating_Cooling')]) {
    if (!have.contains(s.Id)) add.add(new ServiceResourceSkill(ServiceResourceId = r.Id, SkillId = s.Id, SkillLevel = 5, EffectiveStartDate = Datetime.now().addDays(-1)));
}
insert add;
System.debug('OMNI_OK skills=' + (have.size() + add.size()));