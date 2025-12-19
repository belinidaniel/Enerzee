/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-16-2025
 * @last modified by  : Daniel Belini
**/
public class InstalacaoTaskBO {

    public static void createTasks(List<Instalacao__c> newRecords, Map<Id, Instalacao__c> oldMap){
        if(newRecords == null || newRecords.isEmpty()){
            return;
        }

        ProjetoBO.TaskProjectTable taskTable = ProjetoBO.getTaskTableFromStaticResource('TabelaTarefasInstalacao');
        if(taskTable == null || taskTable.tableLines == null || taskTable.tableLines.isEmpty()){
            return;
        }

        Map<String, List<ProjetoBO.TaskProjectTableLine>> statusToTemplates = new Map<String, List<ProjetoBO.TaskProjectTableLine>>();
        Set<String> statusesToWatch = new Set<String>();
        for(ProjetoBO.TaskProjectTableLine line : taskTable.tableLines){
            if(line == null){
                continue;
            }

            String status = normalizeKey(line.Status);

            if(String.isBlank(status)){
                continue;
            }

            statusesToWatch.add(status);

            if(!statusToTemplates.containsKey(status)){
                statusToTemplates.put(status, new List<ProjetoBO.TaskProjectTableLine>());
            }
            statusToTemplates.get(status).add(line);
        }

        Map<String, String> statusCodeToStatus = ProjetoBO.getStatusCodeToStatusMap();
        Map<String, String> statusToStatusCode = ProjetoBO.getStatusToStatusCodeMap();
        Map<String, Group> queueMap = ProjetoUtils.getQueueIdByName();

        Set<Id> projectIds = new Set<Id>();
        Set<Id> userIds = new Set<Id>();

        for(Instalacao__c inst : newRecords){
            if(inst.Projeto__c != null){
                projectIds.add(inst.Projeto__c);
            }
            if(inst.GestorObra__c != null){
                userIds.add(inst.GestorObra__c);
            }
        }

        Map<Id, Projeto__c> projectById = new Map<Id, Projeto__c>();
        if(!projectIds.isEmpty()){
            for(Projeto__c proj : [
                SELECT Id, RecordTypeId, GestorObra__c, Projetista__c, Status__c
                FROM Projeto__c
                WHERE Id IN :projectIds
            ]){
                projectById.put(proj.Id, proj);
                if(proj.GestorObra__c != null){
                    userIds.add(proj.GestorObra__c);
                }
                if(proj.Projetista__c != null){
                    userIds.add(proj.Projetista__c);
                }
            }
        }

        // Mapeia assuntos já existentes por instalação (case-insensitive)
        Map<Id, Set<String>> existingSubjectsByInst = new Map<Id, Set<String>>();
        Map<Id, Boolean> delegarClosedByInst = new Map<Id, Boolean>();
        if (!newRecords.isEmpty()) {
            Set<Id> instIds = new Set<Id>();
            for (Instalacao__c inst : newRecords) {
                instIds.add(inst.Id);
            }
            for (Task t : [
                SELECT Id, Subject, WhatId, IsClosed, Status
                FROM Task
                WHERE WhatId IN :instIds
                    AND IsDeleted = false
            ]) {
                String norm = t.Subject == null ? '' : t.Subject.trim().toLowerCase();
                if (!existingSubjectsByInst.containsKey(t.WhatId)) {
                    existingSubjectsByInst.put(t.WhatId, new Set<String>());
                }
                existingSubjectsByInst.get(t.WhatId).add(norm);

                if (isDelegarGestorSubject(norm)) {
                    Boolean isCompleted = t.IsClosed || (t.Status != null && t.Status.toLowerCase() == TaskUtils.STATUS_CONCLUIDO.toLowerCase());
                    if (isCompleted) {
                        delegarClosedByInst.put(t.WhatId, true);
                    }
                }
            }
        }

        Map<Id, User> userById = fetchUsers(userIds);

        List<Task> tasksToInsert = new List<Task>();
        for(Instalacao__c inst : newRecords){
            if(isInactive(userById.get(inst.GestorObra__c))){
                inst.addError('Usuário GESTOR DE OBRA está inativo.');
                continue;
            }

            Projeto__c relatedProject = projectById.get(inst.Projeto__c);

            if(!isStatusChanging(inst, oldMap != null ? oldMap.get(inst.Id) : null)){
                continue;
            }

            String statusKey = resolveStatusKey(inst.Status__c, statusToStatusCode);
            if(String.isBlank(statusKey)){
                continue;
            }

            if(statusesToWatch.contains(statusKey)){
                List<ProjetoBO.TaskProjectTableLine> templates = statusToTemplates.get(statusKey) != null ? statusToTemplates.get(statusKey) : new List<ProjetoBO.TaskProjectTableLine>();
                templates.sort(new ProjetoBO.TaskProjectTableLineComparator());
                Map<String, User> roleMap = buildRoleMap(inst, relatedProject, userById);
                Set<String> existingSubjects = existingSubjectsByInst.containsKey(inst.Id) ? existingSubjectsByInst.get(inst.Id) : new Set<String>();

                Boolean isPlanejamentoObra = statusKey == normalizeKey('STATUS_PLANEJAMENTO_DE_OBRA');
                Boolean delegarClosed = delegarClosedByInst.containsKey(inst.Id) && delegarClosedByInst.get(inst.Id);

                for(ProjetoBO.TaskProjectTableLine line : templates){
                    if(line == null || String.isBlank(line.Assunto)){
                        continue;
                    }

                    String normSubject = line.Assunto.trim().toLowerCase();
                    if (existingSubjects.contains(normSubject)) {
                        continue;
                    }

                    Boolean isDelegarGestor = isDelegarGestorSubject(normSubject);
                    if (isPlanejamentoObra && !isDelegarGestor && (!delegarClosed || inst.GestorObra__c == null)) {
                        continue;
                    }

                    List<String> interestedList = parseInterested(line.Interessados);
                    Task newTask = createTask(line, inst, relatedProject, interestedList, roleMap, queueMap);
                    if(newTask != null){
                        tasksToInsert.add(newTask);
                        existingSubjects.add(normSubject);
                        existingSubjectsByInst.put(inst.Id, existingSubjects);
                    }
                }
            }
        }

        if(!tasksToInsert.isEmpty()){
            insert tasksToInsert;
        }
    }

    private static Task createTask(
        ProjetoBO.TaskProjectTableLine line,
        Instalacao__c inst,
        Projeto__c project,
        List<String> interestedList,
        Map<String, User> roleToUser,
        Map<String, Group> queueMap
    ){
        Id ownerId = TaskTemplateUtils.resolveOwner(line, roleToUser, queueMap, inst);
        if(ownerId == null){
            String msg = 'Não foi possível definir o proprietário da tarefa "' + line.Assunto + '" (Responsável: ' +
                (line.Responsavel != null ? line.Responsavel : 'não informado') +
                ' | TipoProprietario: ' + (line.TipoDeProprietario != null ? line.TipoDeProprietario : 'não informado') +
                '). Verifique se o usuário/fila está ativo ou existe na org.';
            inst.addError(msg);
            return null;
        }

        String tipoObra = project != null && project.RecordTypeId != null ?
            Schema.getGlobalDescribe().get('Projeto__c').getDescribe().getRecordTypeInfosById().get(project.RecordTypeId).getName() :
            null;

        Task task = new Task(
            TipoObraProjeto__c     = tipoObra,
            StatusProjeto__c       = inst.Status__c,
            Subject                = line.Assunto,
            Description            = line.Acoes,
            WhatId                 = inst.Id,
            PrazoDiasUteis__c      = line.PrazoDiasUteis,
            OwnerId                = ownerId
        );

        Integer daysToConsiderActivity = TaskTemplateUtils.parseInteger(
            String.valueOf(task.PrazoDiasUteis__c),
            TaskTemplateUtils.parseInteger(line.DataVencimentoDMais, 0)
        );

        Date baseDate = System.today();
        task.ActivityDate = TaskBO.getActivityDateBasedOnWorkingDays(baseDate, daysToConsiderActivity);
        if(Schema.SObjectType.Task.fields.getMap().containsKey('HoraVencimento__c')){
            task.put('HoraVencimento__c', TaskTemplateUtils.defaultDueTime());
        }

        if(interestedList != null && !interestedList.isEmpty()){
            for(Integer i = 0; i < interestedList.size(); i++){
                User user = roleToUser != null ? roleToUser.get(interestedList[i]) : null;
                String name = user != null ? user.Name : interestedList[i];

                if(i == 0){
                    task.ResponsavelReceber__c = name;
                } else if (i == 1){
                    task.ResponsavelAcompanhar__c = name + ' / ';
                } else {
                    task.ResponsavelAcompanhar__c += name;
                }
            }
        }

        return task;
    }

    private static Map<String, User> buildRoleMap(Instalacao__c inst, Projeto__c project, Map<Id, User> userById){
        return new Map<String, User>{
            'GESTOR_DE_OBRAS' => userById != null ? userById.get(inst.GestorObra__c) : null,
            'PROJETISTA'      => project != null && userById != null ? userById.get(project.Projetista__c) : null
        };
    }

    public static void createPlanningTasksAfterDelegar(Id instalacaoId) {
        if (instalacaoId == null) {
            return;
        }

        Instalacao__c inst = [
            SELECT Id, Status__c, Projeto__c, GestorObra__c
            FROM Instalacao__c
            WHERE Id = :instalacaoId
            LIMIT 1
        ];

        Projeto__c relatedProject = null;
        if (inst.Projeto__c != null) {
            relatedProject = [
                SELECT Id, RecordTypeId, GestorObra__c, Projetista__c, Status__c
                FROM Projeto__c
                WHERE Id = :inst.Projeto__c
                LIMIT 1
            ];
        }

        ProjetoBO.TaskProjectTable taskTable = ProjetoBO.getTaskTableFromStaticResource('TabelaTarefasInstalacao');
        if (taskTable == null || taskTable.tableLines == null || taskTable.tableLines.isEmpty()) {
            return;
        }

        Map<String, List<ProjetoBO.TaskProjectTableLine>> statusToTemplates = new Map<String, List<ProjetoBO.TaskProjectTableLine>>();
        for (ProjetoBO.TaskProjectTableLine line : taskTable.tableLines) {
            if (line == null) {
                continue;
            }
            String status = normalizeKey(line.Status);
            if (String.isBlank(status)) {
                continue;
            }
            if (!statusToTemplates.containsKey(status)) {
                statusToTemplates.put(status, new List<ProjetoBO.TaskProjectTableLine>());
            }
            statusToTemplates.get(status).add(line);
        }

        Map<String, String> statusToStatusCode = ProjetoBO.getStatusToStatusCodeMap();
        String statusKey = resolveStatusKey(inst.Status__c, statusToStatusCode);
        if (String.isBlank(statusKey)) {
            return;
        }
        statusKey = normalizeKey(statusKey);

        if (statusKey != normalizeKey('STATUS_PLANEJAMENTO_DE_OBRA')) {
            return;
        }

        List<ProjetoBO.TaskProjectTableLine> templates = statusToTemplates.get(statusKey);
        if (templates == null || templates.isEmpty()) {
            return;
        }
        templates.sort(new ProjetoBO.TaskProjectTableLineComparator());

        if (inst.GestorObra__c == null) {
            return;
        }

        Map<String, Group> queueMap = ProjetoUtils.getQueueIdByName();
        Set<Id> userIds = new Set<Id>();
        if (inst.GestorObra__c != null) {
            userIds.add(inst.GestorObra__c);
        }
        if (relatedProject != null) {
            if (relatedProject.GestorObra__c != null) {
                userIds.add(relatedProject.GestorObra__c);
            }
            if (relatedProject.Projetista__c != null) {
                userIds.add(relatedProject.Projetista__c);
            }
        }
        Map<Id, User> userById = fetchUsers(userIds);
        Map<String, User> roleMap = buildRoleMap(inst, relatedProject, userById);

        Map<String, Boolean> existingSubjects = new Map<String, Boolean>();
        for (Task t : [
            SELECT Id, Subject
            FROM Task
            WHERE WhatId = :inst.Id
                AND IsDeleted = false
        ]) {
            String norm = t.Subject == null ? '' : t.Subject.trim().toLowerCase();
            existingSubjects.put(norm, true);
        }

        List<Task> tasksToInsert = new List<Task>();
        for (ProjetoBO.TaskProjectTableLine line : templates) {
            if (line == null || String.isBlank(line.Assunto)) {
                continue;
            }
            String normSubject = line.Assunto.trim().toLowerCase();
            if (existingSubjects.containsKey(normSubject)) {
                continue;
            }
            if (isDelegarGestorSubject(normSubject)) {
                continue;
            }

            List<String> interestedList = parseInterested(line.Interessados);
            Task newTask = createTask(line, inst, relatedProject, interestedList, roleMap, queueMap);
            if (newTask != null) {
                tasksToInsert.add(newTask);
                existingSubjects.put(normSubject, true);
            }
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }

    private static Boolean isDelegarGestorSubject(String normalizedSubject) {
        if (String.isBlank(normalizedSubject)) {
            return false;
        }
        return normalizedSubject == TaskUtils.SUBJECT_DELEGAR_GESTOR_DE_OBRAS.toLowerCase();
    }

    private static String resolveStatusKey(String statusLabel, Map<String, String> statusToStatusCode) {
        if (String.isBlank(statusLabel) || statusToStatusCode == null) {
            return null;
        }
        String direct = statusToStatusCode.get(statusLabel);
        if (!String.isBlank(direct)) {
            return normalizeKey(direct);
        }
        String normLabel = normalizeKey(statusLabel);
        for (String key : statusToStatusCode.keySet()) {
            if (normalizeKey(key) == normLabel) {
                return normalizeKey(statusToStatusCode.get(key));
            }
        }
        return null;
    }

    private static List<String> parseInterested(String interested){
        if(String.isBlank(interested)){
            return new List<String>();
        }
        return new List<String>(interested.split(';'));
    }

    private static Boolean isStatusChanging(Instalacao__c newInst, Instalacao__c oldInst){
        if(oldInst == null){
            return true;
        }
        return newInst.Status__c != oldInst.Status__c;
    }

    private static String normalizeKey(String value){
        if(String.isBlank(value)){
            return '';
        }
        // Normaliza espaços e hifens para tratar variações de rótulo (ex.: "Obra concluída - Aguardando troca de medidor")
        return value.trim().replaceAll('[\\s-]+', '_').toUpperCase();
    }

    private static Map<Id, User> fetchUsers(Set<Id> userIds){
        Map<Id, User> result = new Map<Id, User>();
        if(userIds == null || userIds.isEmpty()){
            return result;
        }

        for(User userRecord : [
            SELECT Id, Email, Name, IsActive
            FROM User
            WHERE Id IN :userIds
        ]){
            result.put(userRecord.Id, userRecord);
        }
        return result;
    }

    private static Boolean isInactive(User userRecord){
        return userRecord != null && !userRecord.IsActive;
    }
}
