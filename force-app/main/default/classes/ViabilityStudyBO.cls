/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-18-2025
 * @last modified by  : Daniel Belini
**/
public class ViabilityStudyBO {

    private static final String STATIC_RESOURCE_NAME = 'TabelaTarefasViabilidade';

    private static Map<String, Group> queueIdentifierToGroup;
    private static Map<String, RoleAssignmentState> roleAssignmentStateByIdentifier = new Map<String, RoleAssignmentState>();
    private static Map<String, User> userEmailToUser = new Map<String, User>();

    @TestVisible private static TaskViabilityTable taskTableOverride;

    @TestVisible private static void resetTestState(){
        queueIdentifierToGroup = null;
        roleAssignmentStateByIdentifier = new Map<String, RoleAssignmentState>();
        userEmailToUser = new Map<String, User>();
    }

    public static void createTasks(List<ViabilityStudy__c> newRecords, Map<Id, ViabilityStudy__c> oldRecordsMap){
        if(newRecords == null || newRecords.isEmpty()){
            return;
        }

        TaskViabilityTable taskTable = getTaskViabilityTableFromStaticResource();

        if(taskTable == null || taskTable.tableLines == null || taskTable.tableLines.isEmpty()){
            return;
        }

        Map<String, Map<String, List<TaskViabilityTableLine>>> typeToStatusTemplates = new Map<String, Map<String, List<TaskViabilityTableLine>>>();

        for(TaskViabilityTableLine line : taskTable.tableLines){
            if(line == null){
                continue;
            }

            String typeKey = normalizeViabilityType(line.TipoViabilidade);
            String statusKey = normalizeStatusCode(line.Status);

            if(String.isBlank(typeKey) || String.isBlank(statusKey) || String.isBlank(line.Assunto)){
                continue;
            }

            if(!typeToStatusTemplates.containsKey(typeKey)){
                typeToStatusTemplates.put(typeKey, new Map<String, List<TaskViabilityTableLine>>());
            }

            Map<String, List<TaskViabilityTableLine>> statusToTemplates = typeToStatusTemplates.get(typeKey);

            if(!statusToTemplates.containsKey(statusKey)){
                statusToTemplates.put(statusKey, new List<TaskViabilityTableLine>());
            }

            statusToTemplates.get(statusKey).add(line);
        }

        if(typeToStatusTemplates.isEmpty()){
            return;
        }

        Map<String, String> statusLabelToCode = getStatusLabelToCodeMap();

        Set<Id> viabilityIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();

        for(ViabilityStudy__c viability : newRecords){
            viabilityIds.add(viability.Id);
            if(viability.Opportunity__c != null){
                opportunityIds.add(viability.Opportunity__c);
            }
        }

        Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>();
        if(!opportunityIds.isEmpty()){
            for(Opportunity opp : [
                SELECT  Id,
                        RecordType.DeveloperName,
                        RecordType.Name,
                        ViabilityStudyOwner__c
                FROM    Opportunity
                WHERE   Id IN :opportunityIds
            ]){
                opportunityById.put(opp.Id, opp);
            }
        }

        Map<Id, Set<String>> existingSubjectsByViability = new Map<Id, Set<String>>();
        if(!viabilityIds.isEmpty()){
            for(Task task : [
                SELECT  Id, Subject, WhatId
                FROM    Task
                WHERE   WhatId IN :viabilityIds
            ]){
                if(!existingSubjectsByViability.containsKey(task.WhatId)){
                    existingSubjectsByViability.put(task.WhatId, new Set<String>());
                }
                existingSubjectsByViability.get(task.WhatId).add(task.Subject);
            }
        }

        Map<String, Group> queueMap = getQueueIdentifierMap();
        List<Task> tasksToInsert = new List<Task>();

        for(ViabilityStudy__c viability : newRecords){
            ViabilityStudy__c oldViability = oldRecordsMap != null ? oldRecordsMap.get(viability.Id) : null;

            if(oldViability != null && viability.StatusFeasibility__c == oldViability.StatusFeasibility__c){
                continue;
            }

            Opportunity opportunity = opportunityById.get(viability.Opportunity__c);
            String typeKey = resolveViabilityTypeKey(viability, opportunity);

            if(String.isBlank(typeKey)){
                continue;
            }

            Map<String, List<TaskViabilityTableLine>> statusToTemplates = typeToStatusTemplates.get(typeKey);
            if(statusToTemplates == null){
                continue;
            }

            String statusCode = statusLabelToCode.get(viability.StatusFeasibility__c);
            if(String.isBlank(statusCode)){
                continue;
            }

            List<TaskViabilityTableLine> templates = statusToTemplates.get(statusCode);
            if(templates == null || templates.isEmpty()){
                continue;
            }

            Set<String> existingSubjects = existingSubjectsByViability.containsKey(viability.Id) ?
                existingSubjectsByViability.get(viability.Id) :
                new Set<String>();

            for(TaskViabilityTableLine templateLine : templates){
                if(templateLine == null || String.isBlank(templateLine.Assunto)){
                    continue;
                }

                if(existingSubjects.contains(templateLine.Assunto)){
                    continue;
                }

                if(!shouldCreateTaskForSubject(templateLine.Assunto, viability)){
                    continue;
                }

                Id ownerId = resolveTaskOwner(templateLine, viability, opportunity, queueMap);
                if(ownerId == null){
                    viability.addError('É necessário informar um usuário, fila ou papel ativo para criar a tarefa "' + templateLine.Assunto + '".');
                    continue;
                }

                Task task = new Task(
                    Subject           = templateLine.Assunto,
                    Description       = templateLine.Acoes,
                    WhatId            = viability.Id,
                    OwnerId           = ownerId,
                    PrazoDiasUteis__c = templateLine.PrazoDiasUteis
                );

                if(!String.isBlank(templateLine.Observacoes)){
                    task.Observacoes__c = templateLine.Observacoes;
                }

                Integer daysToConsiderActivity = parseInteger(templateLine.DataVencimentoDMais, 10);
                task.ActivityDate = TaskBO.getActivityDateBasedOnWorkingDays(System.today(), daysToConsiderActivity);

                List<String> interestedList = parseInterested(templateLine.Interessados);
                populateInterestedFields(task, interestedList);

                tasksToInsert.add(task);
                existingSubjects.add(templateLine.Assunto);
                existingSubjectsByViability.put(viability.Id, existingSubjects);
            }
        }

        if(!tasksToInsert.isEmpty()){
            insert tasksToInsert;
        }
    }

    public static void syncOpportunityInstalledPower(List<ViabilityStudy__c> newRecords, Map<Id, ViabilityStudy__c> oldRecordsMap){
        if(newRecords == null || newRecords.isEmpty()){
            return;
        }

        Map<Id, Opportunity> updatesByOpportunityId = new Map<Id, Opportunity>();

        for(ViabilityStudy__c viability : newRecords){
            if(viability == null || String.isBlank(viability.Opportunity__c)){
                continue;
            }

            Decimal newKwp = viability.InstalledPowerKwp__c;
            Decimal oldKwp = oldRecordsMap != null && oldRecordsMap.containsKey(viability.Id) ?
                oldRecordsMap.get(viability.Id).InstalledPowerKwp__c :
                null;

            Boolean changed =
                (newKwp == null && oldKwp != null) ||
                (newKwp != null && oldKwp == null) ||
                (newKwp != null && oldKwp != null && newKwp != oldKwp);

            if(!changed){
                continue;
            }

            Opportunity oppUpdate = new Opportunity(
                Id = viability.Opportunity__c,
                PotenciaPicoSistema__c = newKwp
            );
            updatesByOpportunityId.put(oppUpdate.Id, oppUpdate);
        }

        if(!updatesByOpportunityId.isEmpty()){
            update updatesByOpportunityId.values();
        }
    }

    private static Integer parseInteger(String value, Integer defaultValue){
        if(String.isBlank(value)){
            return defaultValue;
        }

        String sanitized = value.replaceAll('\n', '').replaceAll('\t', '').replaceAll('\r', '').trim();

        if(sanitized == ''){
            return defaultValue;
        }

        try{
            return Integer.valueOf(sanitized);
        } catch (Exception ex){
            return defaultValue;
        }
    }

    private static List<String> parseInterested(String interessados){
        if(String.isBlank(interessados)){
            return new List<String>();
        }

        List<String> interestedList = new List<String>();
        for(String entry : interessados.split(';')){
            if(!String.isBlank(entry)){
                interestedList.add(entry.trim());
            }
        }
        return interestedList;
    }

    private static Boolean shouldCreateTaskForSubject(String subject, ViabilityStudy__c viability){
        if(String.isBlank(subject)){
            return true;
        }

        String normalizedSubject = subject.trim().toLowerCase();

        if(normalizedSubject == 'solicitar novo integrador'){
            if(viability == null || String.isBlank(viability.OwnTeamThirdParty__c)){
                return false;
            }

            String option = viability.OwnTeamThirdParty__c.trim().toLowerCase();
            return option == 'nao_cadastrado' || option == 'não cadastrado';
        }

        if(normalizedSubject == 'confirmação de lançamento de nf' ||
            normalizedSubject == 'confirmação de lancaçamento de nf'){
            if(viability == null || String.isBlank(viability.OwnTeamThirdParty__c)){
                return false;
            }

            String option = viability.OwnTeamThirdParty__c.trim().toLowerCase();
            return option != 'enerzee' && option != 'consultor';
        }

        return true;
    }

    private static void populateInterestedFields(Task task, List<String> interestedList){
        if(task == null || interestedList == null || interestedList.isEmpty()){
            return;
        }

        for(Integer index = 0; index < interestedList.size(); index++){
            String name = interestedList[index];
            if(index == 0){
                task.ResponsavelReceber__c = name;
            } else if(index == 1){
                task.ResponsavelAcompanhar__c = name;
            } else {
                task.ResponsavelAcompanhar__c =
                    String.isBlank(task.ResponsavelAcompanhar__c) ?
                    name :
                    task.ResponsavelAcompanhar__c + '; ' + name;
            }
        }
    }

    private static Id resolveTaskOwner(
        TaskViabilityTableLine line,
        ViabilityStudy__c viability,
        Opportunity opportunity,
        Map<String, Group> queueMap
    ){
        String ownerType = normalizeOwnerType(line.TipoProprietario);

        if(ownerType == 'QUEUE'){
            Group queue = queueMap.get(line.Responsavel);
            if(queue == null){
                queue = queueMap.get(sanitizeIdentifier(line.Responsavel));
            }
            return queue != null ? queue.Id : null;
        }

        if(ownerType == 'ROLE'){
            Id userId = getUserIdForRole(line.Responsavel);
            return userId;
        }

        if(ownerType == 'USUARIO'){
            if(line.Responsavel != null && line.Responsavel.trim().equalsIgnoreCase('OWNER')){
                if(viability.Owner__c != null){
                    return viability.Owner__c;
                }
                if(opportunity != null && opportunity.ViabilityStudyOwner__c != null){
                    return opportunity.ViabilityStudyOwner__c;
                }
                if(viability.OwnerId != null){
                    return viability.OwnerId;
                }
            } else {
                User targetUser = getUserByEmail(line.Responsavel);
                if(targetUser != null){
                    return targetUser.Id;
                }
            }
        }

        return null;
    }

    private static Id getUserIdForRole(String roleIdentifier){
        if(String.isBlank(roleIdentifier)){
            return null;
        }

        String trimmed = roleIdentifier.trim();
        RoleAssignmentState state = roleAssignmentStateByIdentifier.get(trimmed);

        if(state == null){
            state = buildRoleAssignmentState(roleIdentifier);
            roleAssignmentStateByIdentifier.put(trimmed, state);

            String sanitized = sanitizeIdentifier(roleIdentifier);
            if(!String.isBlank(sanitized)){
                roleAssignmentStateByIdentifier.put(sanitized, state);
            }

            String underscored = trimmed.replace(' ', '_');
            if(!String.isBlank(underscored)){
                roleAssignmentStateByIdentifier.put(underscored, state);
            }

            state = roleAssignmentStateByIdentifier.get(trimmed);
        }

        if(state == null){
            String sanitized = sanitizeIdentifier(roleIdentifier);
            state = roleAssignmentStateByIdentifier.get(sanitized);
        }

        if(state == null){
            return null;
        }

        return state.nextUserId();
    }

    private static User getUserByEmail(String email){
        if(String.isBlank(email)){
            return null;
        }

        String key = email.trim().toLowerCase();
        if(!userEmailToUser.containsKey(key)){
            List<User> users = [
                SELECT  Id, Email
                FROM    User
                WHERE   Email like :email.trim() +'%'
                AND     IsActive = true
                LIMIT   1
            ];
            if(!users.isEmpty()){
                userEmailToUser.put(key, users[0]);
            } else {
                userEmailToUser.put(key, null);
            }
        }

        return userEmailToUser.get(key);
    }

    private static RoleAssignmentState buildRoleAssignmentState(String roleIdentifier){
        Set<String> identifiers = collectRoleIdentifiers(roleIdentifier);
        if(identifiers.isEmpty()){
            return new RoleAssignmentState(new List<Id>());
        }

        List<UserRole> roles = [
            SELECT  Id
            FROM    UserRole
            WHERE   Name IN :identifiers OR DeveloperName IN :identifiers
        ];

        if(roles.isEmpty()){
            return new RoleAssignmentState(new List<Id>());
        }

        Set<Id> roleIds = new Set<Id>();
        for(UserRole roleRecord : roles){
            roleIds.add(roleRecord.Id);
        }

        if(roleIds.isEmpty()){
            return new RoleAssignmentState(new List<Id>());
        }

        List<User> users = [
            SELECT  Id
            FROM    User
            WHERE   IsActive = true AND UserRoleId IN :roleIds
        ];

        if(users.isEmpty()){
            return new RoleAssignmentState(new List<Id>());
        }

        Set<Id> userIds = new Set<Id>();
        for(User userRecord : users){
            userIds.add(userRecord.Id);
        }

        Map<Id, DateTime> lastAssignmentByUser = new Map<Id, DateTime>();
        if(!userIds.isEmpty()){
            for(AggregateResult result : [
                SELECT  OwnerId ownerId, MAX(CreatedDate) lastCreated
                FROM    Task
                WHERE   OwnerId IN :userIds AND WhatId IN (
                            SELECT Id
                            FROM ViabilityStudy__c
                        )
                GROUP BY OwnerId
            ]){
                lastAssignmentByUser.put(
                    (Id) result.get('ownerId'),
                    (DateTime) result.get('lastCreated')
                );
            }
        }

        List<RoleAssignmentCandidate> candidates = new List<RoleAssignmentCandidate>();
        for(Id userId : userIds){
            candidates.add(new RoleAssignmentCandidate(
                userId,
                lastAssignmentByUser.containsKey(userId) ? lastAssignmentByUser.get(userId) : null
            ));
        }

        candidates.sort();

        List<Id> orderedUserIds = new List<Id>();
        for(RoleAssignmentCandidate candidate : candidates){
            orderedUserIds.add(candidate.userId);
        }

        return new RoleAssignmentState(orderedUserIds);
    }

    private static Set<String> collectRoleIdentifiers(String roleIdentifier){
        Set<String> identifiers = new Set<String>();
        if(String.isBlank(roleIdentifier)){
            return identifiers;
        }

        String trimmed = roleIdentifier.trim();
        if(!String.isBlank(trimmed)){
            identifiers.add(trimmed);
            identifiers.add(trimmed.replace(' ', '_'));
        }

        String sanitized = sanitizeIdentifier(roleIdentifier);
        if(!String.isBlank(sanitized)){
            identifiers.add(sanitized);
        }

        return identifiers;
    }

    private static String normalizeOwnerType(String ownerType){
        if(String.isBlank(ownerType)){
            return 'QUEUE';
        }
        return ownerType.trim().toUpperCase();
    }

    private static Map<String, Group> getQueueIdentifierMap(){
        if(queueIdentifierToGroup == null){
            queueIdentifierToGroup = new Map<String, Group>();
            for(Group queue : [
                SELECT  Id, Name, DeveloperName
                FROM    Group
                WHERE   Type = 'Queue'
            ]){
                addQueueToMap(queue.Name, queue);
                addQueueToMap(queue.DeveloperName, queue);
            }
        }
        return queueIdentifierToGroup;
    }

    private static void addQueueToMap(String key, Group queue){
        if(String.isBlank(key) || queue == null){
            return;
        }
        queueIdentifierToGroup.put(key, queue);

        String sanitized = sanitizeIdentifier(key);
        if(!String.isBlank(sanitized)){
            queueIdentifierToGroup.put(sanitized, queue);
        }
    }

    private static String sanitizeIdentifier(String value){
        if(String.isBlank(value)){
            return null;
        }
        String sanitized = value.replaceAll('[^A-Za-z0-9]', '_');
        sanitized = sanitized.replaceAll('_+', '_');
        return sanitized.toUpperCase();
    }

    private static String resolveViabilityTypeKey(ViabilityStudy__c viability, Opportunity opportunity){
        String typeSource = viability.OpportunityType__c;
        if(String.isBlank(typeSource) && opportunity != null && opportunity.RecordType != null){
            typeSource = opportunity.RecordType.Name;
            if(String.isBlank(typeSource)){
                typeSource = opportunity.RecordType.DeveloperName;
            }
        }
        return normalizeViabilityType(typeSource);
    }

    private static String normalizeViabilityType(String typeValue){
        if(String.isBlank(typeValue)){
            return null;
        }

        String cleaned = typeValue.replace(' ', '_');
        cleaned = cleaned.replaceAll('[^A-Za-z0-9_]', '_');
        cleaned = cleaned.replaceAll('_+', '_').trim();

        if(cleaned.equalsIgnoreCase('SOLAR')){
            return 'Solar';
        }

        Set<String> ezeeKeys = new Set<String>{
            'EEZESOLAR',
            'EEZE_SOLAR',
            'EEZESOLARA',
            'EEZESOLARB',
            'EEZE_SOLAR_A',
            'EEZE_SOLAR_B',
            'EZEE_SOLAR',
            'EEZESOLAR_A',
            'EEZESOLAR_B'
        };

        if(ezeeKeys.contains(cleaned.toUpperCase())){
            return 'Ezee_Solar';
        }

        return cleaned;
    }

    private static String normalizeStatusCode(String statusCode){
        if(String.isBlank(statusCode)){
            return null;
        }
        return statusCode.replaceAll('[^A-Za-z0-9_]', '_').replaceAll('_+', '_').trim().toUpperCase();
    }

    private static Map<String, String> getStatusLabelToCodeMap(){
        Map<String, String> statusLabelToCode = new Map<String, String>();

        statusLabelToCode.put('Agendamento de Visita Técnica', 'AGENDAMENTO_DE_VISITA_TECNICA');
        statusLabelToCode.put('Solicitação de Novo Integrador', 'SOLICITACAO_DE_NOVO_INTEGRADOR');
        statusLabelToCode.put('Visita Agendada', 'VISITA_AGENDADA');
        statusLabelToCode.put('Aguardando Elaboração de Estudo', 'AGUARDANDO_ELABORACAO');
        statusLabelToCode.put('Estudo em Elaboração', 'ESTUDO_EM_ELABORACAO');
        statusLabelToCode.put('Viabilidade Finalizada', 'VIABILIDADE_FINALIZADA');

        return statusLabelToCode;
    }

    public static TaskViabilityTable getTaskViabilityTableFromStaticResource(){
        if(Test.isRunningTest() && taskTableOverride != null){
            return taskTableOverride;
        }

        StaticResource taskTableResource = [
            SELECT  Id, Body
            FROM    StaticResource
            WHERE   Name = :STATIC_RESOURCE_NAME
            LIMIT   1
        ];

        CSVReader reader = new CSVReader(taskTableResource.Body.toString(), ';');

        TaskViabilityTable table = new TaskViabilityTable();
        table.tableLines = new List<TaskViabilityTableLine>();

        reader.readLine();
        String[] row = reader.readLine();

        while(row != null){
            TaskViabilityTableLine line = new TaskViabilityTableLine();
            line.TipoViabilidade     = safeArrayGet(row, 0);
            line.Status              = safeArrayGet(row, 1);
            line.Assunto             = safeArrayGet(row, 2);
            line.Acoes               = safeArrayGet(row, 3);
            line.Observacoes         = safeArrayGet(row, 4);
            line.Responsavel         = safeArrayGet(row, 5);
            line.Interessados        = safeArrayGet(row, 6);
            line.PrazoDiasUteis      = safeArrayGet(row, 7);
            line.DataVencimentoDMais = safeArrayGet(row, 8);
            line.TipoProprietario    = safeArrayGet(row, 9);

            table.tableLines.add(line);
            row = reader.readLine();
        }

        return table;
    }

    private static String safeArrayGet(String[] row, Integer index){
        return row != null && row.size() > index ? String.valueOf(row[index]) : null;
    }

    private class RoleAssignmentState{
        private List<Id> orderedUserIds;
        private Integer nextIndex;

        RoleAssignmentState(List<Id> orderedUserIds){
            this.orderedUserIds = orderedUserIds != null ? orderedUserIds : new List<Id>();
            this.nextIndex = 0;
        }

        Id nextUserId(){
            if(orderedUserIds.isEmpty()){
                return null;
            }
            Id userId = orderedUserIds[nextIndex];
            nextIndex++;
            if(nextIndex >= orderedUserIds.size()){
                nextIndex = 0;
            }
            return userId;
        }
    }

    private class RoleAssignmentCandidate implements Comparable{
        private Id userId;
        private DateTime lastAssigned;

        RoleAssignmentCandidate(Id userId, DateTime lastAssigned){
            this.userId = userId;
            this.lastAssigned = lastAssigned;
        }

        public Integer compareTo(Object other){
            RoleAssignmentCandidate candidate = (RoleAssignmentCandidate) other;

            if(this.lastAssigned == null && candidate.lastAssigned != null){
                return -1;
            }
            if(this.lastAssigned != null && candidate.lastAssigned == null){
                return 1;
            }
            if(this.lastAssigned != null && candidate.lastAssigned != null){
                Long thisTime = this.lastAssigned.getTime();
                Long otherTime = candidate.lastAssigned.getTime();
                if(thisTime < otherTime){
                    return -1;
                }
                if(thisTime > otherTime){
                    return 1;
                }
            }
            return String.valueOf(this.userId).compareTo(String.valueOf(candidate.userId));
        }
    }

    public class TaskViabilityTableLine{
        public String TipoViabilidade;
        public String Status;
        public String Assunto;
        public String Acoes;
        public String Observacoes;
        public String Responsavel;
        public String Interessados;
        public String PrazoDiasUteis;
        public String DataVencimentoDMais;
        public String TipoProprietario;
    }

    public class TaskViabilityTable{
        public List<TaskViabilityTableLine> tableLines;
    }
}
