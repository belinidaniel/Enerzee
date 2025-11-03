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

                    new String[]{ ownerEmail != null ? ownerEmail : 'vitor.avancini@lab065.com' },

                    new String[]{ 'kaique.mathias@lab065.com' }
                ));
            }
        }

        if(!Test.isRunningTest() && messageList.size() > 0) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);
        }

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
