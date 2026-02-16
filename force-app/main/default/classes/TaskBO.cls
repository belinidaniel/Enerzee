/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-16-2025
 * @last modified by  : Daniel Belini
**/
public class TaskBO {
    
    public static Task createTask(Id whatId, String subject, String description, Id ownerId, Date dueDate, String deadline){
        return new Task(
            WhatId            = whatId,
            Subject           = subject,
            Description       = description,
            OwnerId           = ownerId,
            ActivityDate      = dueDate,
            PrazoDiasUteis__c = deadline
        );
    }

    // Valida anexos obrigatórios configurados no CMDT ActivityRequiredDocument__mdt
    @TestVisible
    private static void validateRequiredDocuments(Task taskRecord) {
        if (taskRecord == null || String.isBlank(taskRecord.Subject) || taskRecord.WhatId == null) {
            return;
        }

        List<ActivityRequiredDocument__mdt> configs = [
            SELECT ActivitySubject__c, RequiredFiles__c
            FROM ActivityRequiredDocument__mdt
            WHERE ActivitySubject__c = :taskRecord.Subject
        ];
        if (configs.isEmpty()) {
            return;
        }

        Set<String> required = new Set<String>();
        Map<String, String> requiredRawByNorm = new Map<String, String>();
        for (ActivityRequiredDocument__mdt cfg : configs) {
            if (String.isBlank(cfg.RequiredFiles__c)) continue;
            for (String name : cfg.RequiredFiles__c.split(';')) {
                String norm = normalizeName(name);
                if (!String.isBlank(norm)) {
                    required.add(norm);
                    if (!requiredRawByNorm.containsKey(norm)) {
                        requiredRawByNorm.put(norm, name.trim());
                    }
                }
            }
        }
        if (required.isEmpty()) {
            return;
        }

        Set<String> uploaded = new Set<String>();
        for (OpportunityAttachmentLink__c link : [
            SELECT AttachmentDescription__c, DocRequiredName__c
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(taskRecord.WhatId)
        ]) {
            String sourceName = String.isNotBlank(link.DocRequiredName__c)
                ? link.DocRequiredName__c
                : link.AttachmentDescription__c;
            String norm = normalizeName(sourceName);
            if (!String.isBlank(norm)) {
                uploaded.add(norm);
            }
        }

        Set<String> missing = required.clone();
        missing.removeAll(uploaded);
        if (!missing.isEmpty()) {
            List<String> missingLabels = new List<String>();
            for (String key : missing) {
                if (requiredRawByNorm.containsKey(key)) {
                    missingLabels.add(requiredRawByNorm.get(key));
                } else {
                    missingLabels.add(key);
                }
            }
            taskRecord.addError('Ainda faltam anexar os documentos obrigatórios: ' + String.join(missingLabels, ', '));
        }
    }

    @TestVisible
    private static String normalizeName(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String normalized = value.toLowerCase();
        normalized = normalized
            .replaceAll('[áàãâä]', 'a')
            .replaceAll('[éèêë]', 'e')
            .replaceAll('[íìîï]', 'i')
            .replaceAll('[óòõôö]', 'o')
            .replaceAll('[úùûü]', 'u')
            .replaceAll('[ç]', 'c');
        normalized = normalized.replaceAll('[^a-z0-9]+', '_');
        normalized = normalized.replaceAll('^_+|_+$', '');
        return normalized;
    }

    public static Boolean hasOpenTasks(Id whatId) {
        if (whatId == null) {
            return false;
        }

        String query = 'SELECT Id, Status';
        Boolean hasDispensa = Schema.sObjectType.Task.fields.getMap().containsKey('DispensarAtividade__c');
        if (hasDispensa) {
            query += ', DispensarAtividade__c';
        }
        String statusConcluido = TaskUtils.STATUS_CONCLUIDO;
        query += ' FROM Task WHERE WhatId = :whatId AND IsDeleted = false AND Status != :statusConcluido LIMIT 50';

        List<Task> tasks = Database.query(query);
        if (tasks.isEmpty()) {
            return false;
        }

        for (Task t : tasks) {
            if (hasDispensa) {
                Boolean dispensa = (Boolean)t.get('DispensarAtividade__c');
                if (dispensa == true) {
                    continue;
                }
            }
            return true;
        }

        return false;
    }
    
    public static void preventDuplicateOpenTasks(List<Task> newTasks) {
        if (newTasks == null || newTasks.isEmpty()) {
            return;
        }

        Map<String, List<Task>> keyToTasks = new Map<String, List<Task>>();
        for (Task t : newTasks) {
            if (t.WhatId == null || String.isBlank(t.Subject)) {
                continue;
            }
            String key = String.valueOf(t.WhatId) + '::' + t.Subject.toLowerCase().trim();
            if (!keyToTasks.containsKey(key)) {
                keyToTasks.put(key, new List<Task>());
            }
            keyToTasks.get(key).add(t);
        }

        if (keyToTasks.isEmpty()) {
            return;
        }

        Set<Id> whatIds = new Set<Id>();
        Set<String> subjectsRaw = new Set<String>();
        for (Task t : newTasks) {
            if (t.WhatId != null && !String.isBlank(t.Subject)) {
                whatIds.add(t.WhatId);
                subjectsRaw.add(t.Subject.trim());
            }
        }

        Map<String, Task> existingMap = new Map<String, Task>();
        for (Task existing : [
            SELECT Id, WhatId, Subject, Status
            FROM Task
            WHERE WhatId IN :whatIds
                AND Subject IN :subjectsRaw
                AND Status != :TaskUtils.STATUS_CONCLUIDO
        ]) {
            String key = String.valueOf(existing.WhatId) + '::' + existing.Subject.toLowerCase().trim();
            existingMap.put(key, existing);
        }

        for (String key : keyToTasks.keySet()) {
            if (existingMap.containsKey(key)) {
                for (Task t : keyToTasks.get(key)) {
                    t.addError('Já existe uma atividade em aberto com este assunto para o mesmo registro.');
                }
            }
        }
    }

    public static Date getActivityDateBasedOnWorkingDays(Date startDate, Integer days){        
        Integer daysToAdd = days;
        Date endDate = startDate.addDays(daysToAdd);

        Integer workingDays = 0;
        while(workingDays != (days + 1)){
            workingDays = 0;
            for(Integer i = 0; i <= startDate.daysBetween(endDate); i++){
                Date dt = startDate + i;
                DateTime currDate = DateTime.newInstance(dt.year(), dt.month(), dt.day());
                String todayDay = currDate.format('EEEE');
                if(todayDay != 'Saturday' && todayDay !='Sunday'){
                    workingDays++;
                }
            }
            
            if(workingDays != (days + 1)){
                daysToAdd++;
                endDate = startDate.addDays(daysToAdd);
            }
        }
        return endDate;
    }

    //  Quando uma tarefa do tipo CONTRATAR INTEGRADOR for concluída,
    //      - criar ordem de trabalho do tipo Instalação;
    //      - enviar email para Coordenador de Engenharia e Gestor da Obra avisando sobre a necessidade de despacho manual.
    public static void createWorkOrderContractingIntegrator(List<Task> taskList, Map<Id, Task> oldMap){
        List<WorkOrder> workOrdersToInsert = new List<WorkOrder>();
        
        //monta lista e map pra pegar valores ativos e jogar pelo nome
		List<ServiceTerritory> territorios = [SELECT ID, Name FROM ServiceTerritory WHERE IsActive = true];
        Map<String, ServiceTerritory> mapTerritorio = new Map<String, ServiceTerritory>();
        
        for(ServiceTerritory ter: territorios){
            mapTerritorio.put(ter.Name, ter);
        }
        
        Map<Id, List<Task>> projectIDToTaskList = new Map<Id, List<Task>>();
        for(Task task: taskList){
            if(
                TaskUtils.isSubjectContratarIntegrador(task) && 
                TaskUtils.isTaskBeingConcluded(oldMap.get(task.Id), task)
            ){
                if(!projectIDToTaskList.containsKey(task.WhatId)){
                    projectIDToTaskList.put(task.WhatId, new List<Task>());
                }
                projectIDToTaskList.get(task.WhatId).add(task);
            }
        }
        
        if(!projectIDToTaskList.isEmpty()){
            Map<Id, Id> projectRecordTypeToWorkTypeID = new Map<Id, Id>();
            for(WorkType workType : [
                SELECT  Id, Name 
                FROM    WorkType 
                WHERE   Name LIKE 'Instalação%'
            ]){
                if(workType.Name.contains('Bombeamento')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_BOMBEAMENTO, workType.Id);
                    continue;
                }
                if(workType.Name.contains('Estação de recarga')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_ESTACAO_DE_RECARGA, workType.Id);
                    continue;
                }
                if(workType.Name.contains('Financiamento')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_FINANCIAMENTO, workType.Id);
                    continue;
                }
                if(workType.Name.contains('Padrão de entrada')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_PADRAO_DE_ENTRADA, workType.Id);
                    continue;
                }
                if(workType.Name.contains('Posto de transformação')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_POSTO_DE_TRANSFORMACAO, workType.Id);
                    continue;
                }
                if(workType.Name.contains('Subestação')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_SUBESTACAO, workType.Id);
                    continue;
                }
                if(workType.Name.contains('UFV Micro')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_UFV_MICRO, workType.Id);
                    continue;
                }
                if(workType.Name.contains('UFV Mini acima de 300')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_UFV_MINI_ACIMA_DE_300, workType.Id);
                    continue;
                }
                if(workType.Name.contains('UFV Mini até 300')){
                    projectRecordTypeToWorkTypeID.put(ProjetoUtils.RT_UFV_MINI_ATE_300, workType.Id);
                    continue;
                }
            }
            
            List<Projeto__c> projectList = [ 
                SELECT  Id, Name, Conta__c, Consultor__c, Instalacao__c, GestorObra__c, 
                        Oportunidade__c, Oportunidade__r.MunicipioInstalacao__c, 
                        Oportunidade__r.EstadoInstalacao__c, RecordTypeID
                FROM    Projeto__c 
                WHERE   Id IN :projectIDToTaskList.keySet()
            ];
            Set<Id> constructionManagerIDs = new Set<Id>();
            Map<Id, Projeto__c> projectMap = new Map<Id, Projeto__c>();
            for(Projeto__c project : projectList){
                constructionManagerIDs.add(project.GestorObra__c);
                Id territoryIdentifier;

                territoryIdentifier = 
                    project.Oportunidade__r.MunicipioInstalacao__c != null && 
                    mapTerritorio.get(project.Oportunidade__r.MunicipioInstalacao__c) != null ?

                    mapTerritorio.get(project.Oportunidade__r.MunicipioInstalacao__c).Id :
                    
                    project.Oportunidade__r.EstadoInstalacao__c != null && 
                    mapTerritorio.get(project.Oportunidade__r.EstadoInstalacao__c) != null ?

                    mapTerritorio.get(project.Oportunidade__r.EstadoInstalacao__c).Id : null;
                
                for(Task task : projectIDToTaskList.get(project.id)){
                    WorkOrder workOrder = createWorkOrder(
                        project, 
                        Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Instalacao').getRecordTypeId(),
                        projectRecordTypeToWorkTypeID.get(project.RecordTypeId), 
                        territoryIdentifier
                    );
                    workOrdersToInsert.add(workOrder);

                    projectMap.put(project.Id, project);
                }
            }

            //insert workOrdersToInsert;

            Map<Id, String> constructionManagerIDsToEmails = new Map<Id, String>();
            for(User user : [
                SELECT  Id, Email
                FROM    User
                WHERE   ID IN :constructionManagerIDs
            ]){
                constructionManagerIDsToEmails.put(user.Id, user.Email);
            }
            List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
            for(WorkOrder workOrder : workOrdersToInsert){
                
                messageList.add(EmailUtils.createSingleEmailMessage(
                    'Necessidade de Despacho Manual',

                    'Olá! Uma nova ordem de trabalho do tipo "Instalação" foi criada, ' + 
                    'sendo necessário criar o compromisso de serviço adequado e despachá-lo. Clique no link ' + 
                    'abaixo para conferir.<br><br>' +
                    (URL.getSalesforceBaseUrl().toExternalForm() + '/' + workOrder.Id),

                    new String[]{
                        ProjetoUtils.COORDENADOR_DE_ENGENHARIA.Email,
                        constructionManagerIDsToEmails.get(projectMap.get(workOrder.Projeto__c).GestorObra__c),
                        'elenara.rodrigues@enerzee.com.br'
                    },

                    new String[]{}
                ));
                
            }
            if(!Test.isRunningTest()){
                //Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);
            }
        }
    }


    //  Sempre que uma tarefa do tipo SOLICITAR COMPRA DE MATERIAIS ou SOLICITAR COMPRA DE MATERIAIS COMPLEMENTARES for concluída,
    //      - criar ordem de trabalho do tipo Recebimento de material;
    //      - enviar email para Coordenador de Engenharia avisando sobre a necessidade de despacho manual.
    public static void createWorkOrderRequestMaterialBuy(List<Task> taskList, Map<Id, Task> oldMap){
        List<WorkOrder> workOrdersToInsert = new List<WorkOrder>();

        //monta lista e map pra pegar valores ativos e jogar pelo nome
		List<ServiceTerritory> territorios = [SELECT ID, Name FROM ServiceTerritory WHERE IsActive = true];
        Map<String, ServiceTerritory> mapTerritorio = new Map<String, ServiceTerritory>();
        
        for(ServiceTerritory ter: territorios){
            mapTerritorio.put(ter.Name, ter);
        }
        

        Map<Id, List<Task>> projectIDToTaskList = new Map<Id, List<Task>>();
        for(Task task: taskList){
            if(
                (
                    TaskUtils.isSubjectSolicitarCompraMateriais(task) ||
                    TaskUtils.isSubjectSolicitarCompraMateriaisComplementares(task)
                ) && 
                TaskUtils.isTaskBeingConcluded(oldMap.get(task.Id), task)
            ){
                if(!projectIDToTaskList.containsKey(task.WhatId)){
                    projectIDToTaskList.put(task.WhatId, new List<Task>());
                }
                projectIDToTaskList.get(task.WhatId).add(task);
            }
        }
        
        if(!projectIDToTaskList.isEmpty()){
            WorkType workType;
            for(WorkType wt :[
                SELECT  Id, Name 
                FROM    WorkType 
                WHERE   Name = 'Recebimento de Material'
                LIMIT   1
            ]){
                workType = wt;
            }
            
            List<Projeto__c> projectList = [ 
                SELECT  Id, Name, Conta__c, Consultor__c, Instalacao__c, GestorObra__c,
                        Oportunidade__c, Oportunidade__r.MunicipioInstalacao__c, 
                        Oportunidade__r.EstadoInstalacao__c, RecordTypeID
                FROM    Projeto__c 
                WHERE   Id IN :projectIDToTaskList.keySet()
            ];

            for(Projeto__c project : projectList){
                Id territoryIdentifier;

                territoryIdentifier = 
                    project.Oportunidade__r.MunicipioInstalacao__c != null && 
                    mapTerritorio.get(project.Oportunidade__r.MunicipioInstalacao__c) != null ?

                    mapTerritorio.get(project.Oportunidade__r.MunicipioInstalacao__c).Id :
                    
                    project.Oportunidade__r.EstadoInstalacao__c != null && 
                    mapTerritorio.get(project.Oportunidade__r.EstadoInstalacao__c) != null ?

                    mapTerritorio.get(project.Oportunidade__r.EstadoInstalacao__c).Id : null;

                for(Task task : projectIDToTaskList.get(project.id)){
                    workOrdersToInsert.add(createWorkOrder(
                        project, 
                        Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('RecebimentoMaterial').getRecordTypeId(),
                        workType != null ? workType.Id : null,
                        territoryIdentifier
                    ));
                }
            }

            //insert workOrdersToInsert;


            List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
            for(WorkOrder workOrder : workOrdersToInsert){
                messageList.add(EmailUtils.createSingleEmailMessage(
                    'Necessidade de Despacho Manual',

                    'Olá! Uma nova ordem de trabalho do tipo "Recebimento de Material" foi criada, ' + 
                    'sendo necessário criar o compromisso de serviço adequado e despachá-lo. Clique no link ' + 
                    'abaixo para conferir.<br><br>' +
                    (URL.getSalesforceBaseUrl().toExternalForm() + '/' + workOrder.Id),

                    new String[]{
                        ProjetoUtils.COORDENADOR_DE_ENGENHARIA.Email, 'elenara.rodrigues@enerzee.com.br'
                    },

                    new String[]{}
                ));
            }
            if(!Test.isRunningTest()){
                //Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);
            }
        }
    }


    public static void notifyAfterTaskConclusion(List<Task> taskList, Map<Id, Task> oldMap){
        List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
        for(Task task : taskList){
            if(
                TaskUtils.isTaskBeingConcluded(oldMap.get(task.Id), task) &&
                (
                    task.Subject.contains('Defina quem executará a visita técnica do negócio') ||
                    task.Subject.contains('Acusar recebimento dos dados da visita')
                )
            ){
                messageList.add(
                    EmailUtils.createSingleEmailMessage(
                        'Uma tarefa foi concluída',

                        'Olá! A tarefa de nome "' + task.Subject + '" acaba de ser concluída. ' +
                        'Clique no link abaixo para acessá-la.<br><br>' +
                        (URL.getSalesforceBaseUrl().toExternalForm() + '/' + task.Id),

                        new String[]{'matheus.martins@enerzee.com.br', 'elenara.rodrigues@enerzee.com.br'},

                        new String[]{}
                    )
                );
            }
        }
        
        if(!Test.isRunningTest()){
            Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);
        }
    }

    public static WorkOrder createWorkOrder(Projeto__c project, Id recordTypeId, Id workTypeId, Id serviceTerritoryId){
        WorkOrder workOrder        = new WorkOrder(
            AccountId              = project.Conta__c,
            Consultor__c           = project.Consultor__c,
            InstalacaoAssociada__c = project.Instalacao__c,
            Projeto__c             = project.Id,
            Oportunidade__c        = project.Oportunidade__c,
            Status                 = 'New',
            Priority               = 'Low',
            RecordTypeID           = recordTypeId,
            WorkTypeId             = workTypeId,
            ServiceTerritoryId     = serviceTerritoryId
        );

        return workOrder;
    }

    public static WorkOrder createWorkOrder(Opportunity opportunity, Id recordTypeId, Id workTypeId, Id serviceTerritoryId){
        WorkOrder workOrder        = new WorkOrder(
            AccountId              = opportunity.AccountId,
            Consultor__c           = opportunity.ConsultorOportunidade__c,
            InstalacaoAssociada__c = opportunity.Instalacao__c,
            Oportunidade__c        = opportunity.Id,
            Status                 = 'New',
            Priority               = 'Low',
            RecordTypeID           = recordTypeId,
            WorkTypeId             = workTypeId,
            PostalCode             = opportunity.CEP__c,
            Street                 = opportunity.Logradouro__c,
            city                   = opportunity.MunicipioInstalacao__c,
            state                  = opportunity.EstadoInstalacao__c,
            Country                = 'Brasil',
            ServiceTerritoryId     = serviceTerritoryId
        );

        return workOrder;
    }

     // Método para atualizar a fase do projeto com base nas tarefas concluídas
    public static void updateProjectPhase(List<Task> newRecordList, Map<Id, Task> oldMap) {
        Set<Id> projectIds = new Set<Id>();  // Conjunto para armazenar IDs de projetos

        // Coleta IDs de projetos dos registros de Task novos ou atualizados
        for (Task task : newRecordList) {
            if (task.WhatId != null && isValidProjectId(task.WhatId)) {  // Verifica se é um projeto válido
                projectIds.add(task.WhatId);
            }
        }

        if (projectIds.isEmpty()) return;  // Nenhum projeto válido para processar

        // Consulta projetos a partir dos IDs coletados
        Map<Id, Projeto__c> projects = getProjectsWithTasks(projectIds);

        // Processa cada projeto para verificar a conclusão das tarefas e avançar a fase
        List<Projeto__c> projectsToUpdate = new List<Projeto__c>();
        for (Id projectId : projects.keySet()) {
            Projeto__c project = projects.get(projectId);
            String nextPhase = getNextPhase(project);  // Calcula a próxima fase

            if (nextPhase != null && !nextPhase.equals(project.Status__c)) {
                project.Status__c = nextPhase;  // Avança a fase
                projectsToUpdate.add(project);
            }
        }

        if (!projectsToUpdate.isEmpty()) {
            update projectsToUpdate;  // Atualiza os projetos cujas fases foram alteradas
        }
    }

    // Atualiza o status do projeto e fase da oportunidade ao concluir "APROVAÇÃO DO PROJETO UFV"
    public static void handleAprovacaoProjetoUfv(List<Task> newRecordList, Map<Id, Task> oldMap) {
        if (newRecordList == null || newRecordList.isEmpty()) {
            return;
        }

        Set<Id> projectIds = new Set<Id>();
        for (Task task : newRecordList) {
            if (task.WhatId == null || !isValidProjectId(task.WhatId)) {
                continue;
            }
            if (TaskUtils.isTaskBeingConcluded(oldMap != null ? oldMap.get(task.Id) : null, task)
                && task.Subject != null
                && task.Subject.trim().equalsIgnoreCase(TaskUtils.SUBJECT_APROVACAO_DO_PROJETO_UFV)) {
                projectIds.add(task.WhatId);
            }
        }

        if (projectIds.isEmpty()) {
            return;
        }

        List<Projeto__c> projectsToUpdate = new List<Projeto__c>();
        Set<Id> opportunityIds = new Set<Id>();

        Boolean hasSubStatus = Schema.SObjectType.Projeto__c.fields.getMap().containsKey('SubStatus__c');
        String query = 'SELECT Id, Status__c, Oportunidade__c';
        if (hasSubStatus) {
            query += ', SubStatus__c';
        }
        query += ' FROM Projeto__c WHERE Id IN :projectIds';

        for (Projeto__c project : Database.query(query)) {
            String subStatusValue = hasSubStatus ? (String)project.get('SubStatus__c') : null;
            if (subStatusValue != null && subStatusValue.equalsIgnoreCase('Aprovado')) {
                if (project.Status__c != ProjetoUtils.STATUS_PROJETO_APROVADO) {
                    project.Status__c = ProjetoUtils.STATUS_PROJETO_APROVADO;
                    projectsToUpdate.add(project);
                }
                if (project.Oportunidade__c != null) {
                    opportunityIds.add(project.Oportunidade__c);
                }
            }
        }

        if (!projectsToUpdate.isEmpty()) {
            update projectsToUpdate;
        }

        if (!opportunityIds.isEmpty()) {
            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            for (Opportunity opp : [
                SELECT Id, StageName, RecordTypeId
                FROM Opportunity
                WHERE Id IN :opportunityIds
            ]) {
                String targetStage = OpportunityUtils.resolveStageForProjectCompletion(opp);
                if (opp.StageName == null
                    || !opp.StageName.equalsIgnoreCase(targetStage)) {
                    opp.StageName = targetStage;
                    oppsToUpdate.add(opp);
                }
            }

            if (!oppsToUpdate.isEmpty()) {
                update oppsToUpdate;
            }
        }
    }

    // Funções auxiliares para suportar a lógica principal

    // Verifica se um ID é válido para um projeto específico
    private static Boolean isValidProjectId(Id id) {
        String idPrefix = String.valueOf(id).substring(0, 3);
        return idPrefix == 'a03';  // Substituir por prefixo correto para projetos
    }

    // Retorna um mapa de projetos com suas tasks agregadas
    private static Map<Id, Projeto__c> getProjectsWithTasks(Set<Id> projectIds) {
        Map<Id, Projeto__c> projects = new Map<Id, Projeto__c>();

        for (Projeto__c project : [
            SELECT Id, Status__c, RecordTypeId, (
                SELECT Id, Status FROM Tasks WHERE IsDeleted = false
            )
            FROM Projeto__c WHERE Id IN :projectIds
        ]) {
            projects.put(project.Id, project);
        }

        return projects;
    }

    // Calcula a próxima fase de um projeto com base nas tarefas concluídas
    private static String getNextPhase(Projeto__c project) {
        List<Task> tasks = project.Tasks;  // Todas as tasks associadas
        Integer totalTasks = tasks.size();
        Integer completedTasks = 0;

        for (Task task : tasks) {
            if (task.Status == 'Completed') {
                completedTasks += 1;
            }
        }

        if (totalTasks == completedTasks) {
            Map<String, List<String>> phasesByType = getPhasesByType();
            List<String> phases = phasesByType.get(project.RecordTypeId);

            if (phases != null) {
                Integer currentIndex = phases.indexOf(project.Status__c);

                if (currentIndex >= 0 && currentIndex + 1 < phases.size()) {
                    return phases.get(currentIndex + 1);  // Próxima fase
                }
            }
        }

        return null;  // Sem mudança de fase
    }

    private static Map<String, List<String>> getPhasesByType() {
        // Mapa para armazenar as fases por Record Type
        Map<String, List<String>> phasesByType = new Map<String, List<String>>();
    
        phasesByType.put('Bombeamento', 
            new List<String>{'Planejamento', 'Obra em execução', 'Obra Concluida'}
        );
        
        phasesByType.put('EstacaoRecarga', 
            new List<String>{'Planejamento', 'Obra em execução', 'Obra Concluida'}
        );
        
        phasesByType.put('Financiamento', 
            new List<String>{'Planejamento', 'Elaboração de projeto', 'Projeto em análise', 'Projeto aprovado'}
        );
        
        phasesByType.put('PadraoEntrada', 
            new List<String>{'Planejamento', 'Elaboração de projeto', 'Projeto protocolado', 'Obra em execução', 'Ligação solicitada', 'Obra Concluida'}
        );
        
        phasesByType.put('PostoTransformacao', 
            new List<String>{'Planejamento', 'Elaboração de projeto', 'Projeto aprovado', 'Obra em execução', 'Aguardando vistoria', 'Ligação solicitada', 'Obra Concluida'}
        );
        
        phasesByType.put('Subestacao', 
            new List<String>{'Planejamento', 'Elaboração de projeto', 'Projeto protocolado', 'Projeto aprovado', 'Obra em execução', 'Aguardando vistoria', 'Ligação solicitada', 'Obra Concluida'}
        );
        
        phasesByType.put('UFVMicro', 
            new List<String>{'Planejamento', 'Projetos em elaboração', 'Projeto em análise', 'Projeto aprovado', 'Obra Concluida - Aguardando troca de medidor', 'Usina operando', 'Obra Concluida'}
        );
        
        phasesByType.put('UFVacima300', 
            new List<String>{'Planejamento', 'Projetos em elaboração', 'Projeto aprovado', 'Obra Concluida - Aguardando troca de medidor', 'Usina operando', 'Obra Concluida'}
        );
        
        phasesByType.put('UFVmini300', 
            new List<String>{'Planejamento', 'Projetos em elaboração', 'Projeto em análise', 'Projeto aprovado', 'Obra Concluida - Aguardando troca de medidor', 'Usina operando', 'Obra Concluida'}
        );
        
        return phasesByType;
    }
    
    

    // Consulta os IDs de Record Types com base em seus nomes
    static Map<String, String> getRecordTypeIds() {
        Map<String, String> recordTypeNamesToIds = new Map<String, String>();
        
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Projeto__c'
        ]) {
            recordTypeNamesToIds.put(rt.DeveloperName, rt.Id);
        }
        
        return recordTypeNamesToIds;
    }

    /*public static void reassignTaskOwner(List<Task> taskList) {
        for (Task t : taskList) {
            if (t.CreatedById == UserInfo.getUserId()) {
                t.OwnerId = t.CreatedById; // Reatribui a tarefa ao criador
            }
        }
    }*/

    public static void checkTaskCloser(List<Task> taskList, Map<Id, Task> oldMap){

        Id closerUserId = [
            SELECT  Id
            FROM    User
            WHERE   Email like 'wagner.sampaio@enerzee.com.br%'
            LIMIT   1
        ].Id;

        List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
        for (Task Tarefa : taskList) {
            if (
                TaskUtils.isTaskBeingConcluded(oldMap.get(Tarefa.Id), Tarefa) &&
                (
                    Tarefa.Subject.contains('Ligação de follow-up') &&
                    Tarefa.OwnerId == closerUserId && 
                    Tarefa.LastModifiedById == closerUserId &&
                    Tarefa.WhatId != null
                )
            ){
                Opportunity opp = [SELECT Name, Owner.Name, Owner.Email FROM Opportunity WHERE Id =: Tarefa.WhatId LIMIT 1];
                String ownerEmail = opp.Owner.Email;

                messageList.add(EmailUtils.createSingleEmailMessage(
                    'Alerta de interação do Closer - ' + opp.Name,

                    'Olá, '+ opp.Owner.Name+'!<br>' +
                    'Uma nova oportunidade foi efetivada no Salesforce pelo fechador.<br><br>' + 
                    'Clique no link abaixo para conferir.<br>' +
                    (URL.getSalesforceBaseUrl().toExternalForm() + '/lightning/r/Opportunity/' + Tarefa.WhatId + '/view'),

                    new String[]{ ownerEmail != null ? ownerEmail : 'daniel.belini@enerzee.com.br' },

                    new String[]{ 'daniel.belini@enerzee.com.br' }
                ));
            }
        }

        if(!Test.isRunningTest() && messageList.size() > 0) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);
        }

    }

    // Impede concluir tarefas enquanto houver campos obrigatórios de seções marcadas como required no Field Set.
    public static void validateRequiredFieldSetsOnCompletion(List<Task> taskList, Map<Id, Task> oldMap) {
        if (taskList == null || taskList.isEmpty()) {
            return;
        }

        for (Task taskRecord : taskList) {
            Task oldTask = oldMap != null ? oldMap.get(taskRecord.Id) : null;
            if (!TaskUtils.isTaskBeingConcluded(oldTask, taskRecord) || taskRecord.WhatId == null) {
                continue;
            }

            if (Schema.sObjectType.Task.fields.getMap().containsKey('DispensarAtividade__c')
                && (Boolean)taskRecord.get('DispensarAtividade__c') == true) {
                continue;
            }

            validateRequiredDocuments(taskRecord);

            List<FieldRequirement> requiredFields = new List<FieldRequirement>();

            try {
                Schema.SObjectType targetType = taskRecord.WhatId.getSObjectType();
                Schema.DescribeSObjectResult describeResult = targetType.getDescribe();
                String objectApiName = describeResult.getName();
                Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();

                List<FieldSetConfigurationService.SectionConfiguration> sections =
                    FieldSetConfigurationService.getConfigurationForValidation(objectApiName, taskRecord.WhatId, taskRecord.Subject);

                for (FieldSetConfigurationService.SectionConfiguration section : sections) {
                    if (section == null || section.required != true || section.fields == null) {
                        continue;
                    }
                    for (FieldSetConfigurationService.FieldConfiguration fieldConfig : section.fields) {
                        if (fieldConfig == null || fieldConfig.updateable != true) {
                            continue;
                        }

                        Schema.SObjectField fieldToken = fieldMap.get(fieldConfig.apiName);
                        if (fieldToken == null) {
                            continue;
                        }

                        Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
                        if (!fieldDescribe.isAccessible()) {
                            continue;
                        }

                        FieldRequirement req = new FieldRequirement();
                        req.apiName = fieldConfig.apiName;
                        req.label = fieldConfig.label;
                        req.sectionLabel = section.label;
                        requiredFields.add(req);
                    }
                }

                if (requiredFields.isEmpty()) {
                    continue;
                }

                Set<String> queryFields = new Set<String>();
                for (FieldRequirement req : requiredFields) {
                    if (String.isNotBlank(req.apiName)) {
                        queryFields.add(req.apiName);
                    }
                }

                if (objectApiName == 'Projeto__c'
                    && taskRecord.Subject != null
                    && taskRecord.Subject.trim().equalsIgnoreCase(TaskUtils.SUBJECT_APROVACAO_DO_PROJETO_UFV)) {
                    if (fieldMap.containsKey('SubStatus__c')) {
                        queryFields.add('SubStatus__c');
                    }
                    if (fieldMap.containsKey('MotivoSubStatus__c')) {
                        queryFields.add('MotivoSubStatus__c');
                    }
                }

                if (queryFields.isEmpty()) {
                    continue;
                }

                String query = 'SELECT ' + String.join(new List<String>(queryFields), ', ')
                    + ' FROM ' + objectApiName + ' WHERE Id = \'' + String.escapeSingleQuotes((String)taskRecord.WhatId) + '\'';

                SObject targetRecord = Database.query(query);

                Map<String, List<String>> missingBySection = new Map<String, List<String>>();

                // Regra específica: Motivo Sub-Status obrigatório apenas quando Sub-Status é Aprovado Parcialmente / Cancelado / Reprovado.
                if (objectApiName == 'Projeto__c'
                    && taskRecord.Subject != null
                    && taskRecord.Subject.trim().equalsIgnoreCase(TaskUtils.SUBJECT_APROVACAO_DO_PROJETO_UFV)
                    && fieldMap.containsKey('SubStatus__c')
                    && fieldMap.containsKey('MotivoSubStatus__c')) {
                    String subStatusValue = (String)targetRecord.get('SubStatus__c');
                    String motivoValue = (String)targetRecord.get('MotivoSubStatus__c');
                    Boolean requiresMotivo = !String.isBlank(subStatusValue)
                        && (subStatusValue.equalsIgnoreCase('Aprovado Parcialmente')
                            || subStatusValue.equalsIgnoreCase('Cancelado')
                            || subStatusValue.equalsIgnoreCase('Reprovado'));

                    if (!requiresMotivo) {
                        List<FieldRequirement> filtered = new List<FieldRequirement>();
                        for (FieldRequirement r : requiredFields) {
                            if (r == null || r.apiName == 'MotivoSubStatus__c') {
                                continue;
                            }
                            filtered.add(r);
                        }
                        requiredFields = filtered;
                    } else if (String.isBlank(motivoValue)) {
                        taskRecord.addError('Motivo Sub-Status é obrigatório quando Sub-Status é Aprovado Parcialmente ou Cancelado ou Reprovado.');
                        continue;
                    }
                }

                for (FieldRequirement req : requiredFields) {
                    Object value = resolveFieldValue(targetRecord, req.apiName);
                    if (isEmptyValue(value)) {
                        String label = String.isNotBlank(req.label) ? req.label : req.apiName;
                        String sectionLabel = String.isNotBlank(req.sectionLabel) ? req.sectionLabel : 'Seção';

                        if (!missingBySection.containsKey(sectionLabel)) {
                            missingBySection.put(sectionLabel, new List<String>());
                        }
                        missingBySection.get(sectionLabel).add(label);
                    }
                }

                if (!missingBySection.isEmpty()) {
                    List<String> messages = new List<String>();
                    for (String sectionName : missingBySection.keySet()) {
                        messages.add('Preencha os campos obrigatórios na seção \"' + sectionName + '\": ' + String.join(missingBySection.get(sectionName), ', '));
                    }
                    taskRecord.addError(String.join(messages, ' | '));
                }
            } catch (Exception ex) {
                String message = 'Não foi possível finalizar pois não foi preenchida a seção de campos obrigatórios.';
                try {
                    if (!requiredFields.isEmpty()) {
                        Set<String> sections = new Set<String>();
                        for (FieldRequirement r : requiredFields) {
                            if (r != null && String.isNotBlank(r.sectionLabel)) {
                                sections.add(r.sectionLabel);
                            }
                        }
                        if (!sections.isEmpty()) {
                            message = 'Não foi possível finalizar. Preencha os campos obrigatórios nas seções: ' + String.join(new List<String>(sections), ', ') + '.';
                        }
                    }
                    if (String.isBlank(message) || message.contains('seções')) {
                        // Adiciona o erro original para facilitar diagnóstico em QA
                        message += ' (Detalhe técnico: ' + ex.getMessage() + ')';
                    }
                } catch (Exception ignore) {
                    // keep fallback message
                }
                taskRecord.addError(message);
            }
        }
    }

    private static Object resolveFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) {
            return null;
        }

        List<String> parts = fieldPath.split('\\.');
        Object current = record;

        for (String part : parts) {
            if (!(current instanceof SObject)) {
                return null;
            }
            current = ((SObject) current).get(part);
            if (current == null) {
                return null;
            }
        }

        return current;
    }

    private static Boolean isEmptyValue(Object value) {
        if (value == null) {
            return true;
        }
        if (value instanceof String) {
            return String.isBlank((String) value);
        }
        return false;
    }

    public static Boolean taskSubjectExists(Id whatId, String subject) {
        if (whatId == null || String.isBlank(subject)) {
            return false;
        }

        String normalized = subject.trim().toLowerCase();

        for (Task existing : [
            SELECT Subject
            FROM Task
            WHERE WhatId = :whatId
                AND IsDeleted = false
        ]) {
            String existingNorm = existing.Subject == null ? '' : existing.Subject.trim().toLowerCase();
            if (existingNorm == normalized) {
                return true;
            }
        }

        return false;
    }

    private class FieldRequirement {
        String apiName;
        String label;
        String sectionLabel;
    }

    public static void notifyViabilityInvoiceAttachment(Task taskRecord, ContentDocumentLink link){
        if(taskRecord == null || link == null){
            return;
        }

        if(String.isBlank(taskRecord.Subject) || !taskRecord.Subject.equalsIgnoreCase(TaskUtils.SUBJECT_SOLICITAR_PAGAMENTO_DE_INTEGRADOR)){
            return;
        }

        if(taskRecord.WhatId == null || taskRecord.WhatId.getSObjectType() != ViabilityStudy__c.SObjectType){
            return;
        }

        ViabilityStudy__c viability;
        try{
            viability = [
                SELECT  Id, Name, Opportunity__c, Opportunity__r.Name
                FROM    ViabilityStudy__c
                WHERE   Id = :taskRecord.WhatId
                LIMIT   1
            ];
        } catch (Exception ex){
            return;
        }

        ContentVersion fileVersion;
        try{
            fileVersion = [
                SELECT  Id, Title, VersionData, FileExtension
                FROM    ContentVersion
                WHERE   ContentDocumentId = :link.ContentDocumentId
                ORDER BY IsLatest DESC
                LIMIT   1
            ];
        } catch (Exception ex){
            return;
        }

        if(fileVersion == null){
            return;
        }

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setBody(fileVersion.VersionData);
        attachment.setFileName(
            String.isBlank(fileVersion.FileExtension) ?
            fileVersion.Title :
            fileVersion.Title + '.' + fileVersion.FileExtension
        );

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[]{'contabilidade@enerzee.com.br'});
        email.setCcAddresses(new String[]{'financeiro@enerzee.com.br'});
        email.setCcAddresses(new String[]{'Adrilino.silvestre@enerzee.com.br'});
        email.setCcAddresses(new String[]{'daniel.belini@enerzee.com.br'});

        String opportunityName = viability.Opportunity__c != null && viability.Opportunity__r != null ? viability.Opportunity__r.Name : '';
        String subject = 'NF de Integrador anexada - Viabilidade ' + viability.Name;
        if(!String.isBlank(opportunityName)){
            subject += ' / ' + opportunityName;
        }
        email.setSubject(subject);

        String emailBody = 'Olá,<br/><br/>' +
            'A nota fiscal do integrador foi anexada na atividade <strong>"SOLICITAR PAGAMENTO DE INTEGRADOR"</strong> ' +
            'da viabilidade <strong>' + viability.Name + '</strong>';
        if(!String.isBlank(opportunityName)){
            emailBody += ' vinculada à oportunidade <strong>' + opportunityName + '</strong>';
        }
        emailBody += '.<br/><br/>' +
            'O arquivo segue em anexo para conferência.<br/><br/>' +
            'Atenciosamente,<br/>Enerzee CRM';

        email.setHtmlBody(emailBody);
        email.setUseSignature(false);
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});
        
        FeedItem viabilityChatComment = new FeedItem(
            ParentId  = viability.Id,
            Body      = 'E-mail enviado para contabilidade/financeiro com a NF do integrador.',
            Type      = 'TextPost',
            Visibility = 'AllUsers'
        );
        Database.insert(viabilityChatComment, false);

        if(!Test.isRunningTest()){
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });
        }
    }

    public static void updateViabilityStatusOnTaskCompletion(List<Task> taskList, Map<Id, Task> oldMap){
        if(taskList == null || taskList.isEmpty()){ return; }

        Map<Id, ViabilityStudy__c> recordsToUpdate = new Map<Id, ViabilityStudy__c>();

        for(Task taskRecord : taskList){
            if(taskRecord == null || taskRecord.WhatId == null){
                continue;
            }

            if(taskRecord.WhatId.getSObjectType() != ViabilityStudy__c.SObjectType){
                continue;
            }

            Task oldTask = oldMap != null ? oldMap.get(taskRecord.Id) : null;
            if(oldTask == null || !TaskUtils.isTaskBeingConcluded(oldTask, taskRecord)){
                continue;
            }

            String subject = taskRecord.Subject != null ? taskRecord.Subject.trim() : '';

            if(subject.equalsIgnoreCase('AGENDAMENTO DE VISITA')){
                ViabilityStudy__c viabilityUpdate = new ViabilityStudy__c(
                    Id = taskRecord.WhatId,
                    StatusFeasibility__c = 'Visita Agendada'
                );
                recordsToUpdate.put(viabilityUpdate.Id, viabilityUpdate);
                continue;
            }

            if(subject.equalsIgnoreCase('ANEXAR ARQUIVOS DE VIABILIDADE')){
                ViabilityStudy__c viabilityUpdate = new ViabilityStudy__c(
                    Id = taskRecord.WhatId,
                    StatusFeasibility__c = 'Viabilidade Finalizada'
                );
                recordsToUpdate.put(viabilityUpdate.Id, viabilityUpdate);
            }
        }

        if(!recordsToUpdate.isEmpty()){
            update recordsToUpdate.values();
        }
    }
}
