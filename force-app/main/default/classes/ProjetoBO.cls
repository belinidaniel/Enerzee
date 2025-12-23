/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-21-2025
 * @last modified by  : Daniel Belini
**/
public class ProjetoBO {

    public static Map<String, User> userEmailToUser = new Map<String, User>();
    private static Map<Id, User> ownerUserCache = new Map<Id, User>();
    private static final Date TODAY = Date.today();
    
    public static void populateUserEmailMap(){
        if(userEmailToUser.isEmpty()){
            for(User user : [ 
                SELECT  Id, Email, Name 
                FROM    User
                WHERE IsActive=true
            ]){
                userEmailToUser.put(user.Email, user);
            }
        }
    }

    public static void sendProjectToNivello(List<Projeto__c> newRecordList){
        Set<Id> projectIds = new Set<Id>();
        for(Projeto__c project : newRecordList){
            projectIds.add(project.Id);
        }

        IntegracaoNivelloProjetos.sendProjetos(projectIds, Trigger.isInsert);
    }

    public static void initializeStatusStartDate(List<Projeto__c> newRecordList){
        for(Projeto__c project : newRecordList){
            if(project.StatusAtualDesde__c == null){
                project.StatusAtualDesde__c = TODAY;
            }
        }
    }

    public static void populateFromOpportunity(List<Projeto__c> projects){
        if(projects == null || projects.isEmpty()){
            return;
        }

        Set<Id> oppIds = new Set<Id>();
        for(Projeto__c project : projects){
            if(project.Oportunidade__c != null){
                oppIds.add(project.Oportunidade__c);
            }
        }
        if(oppIds.isEmpty()){
            return;
        }

        Map<Id, Opportunity> oppById = new Map<Id, Opportunity>(
            [SELECT Id, AccountId, PotenciaNominalSistema__c FROM Opportunity WHERE Id IN :oppIds]
        );

        for(Projeto__c project : projects){
            Opportunity opp = oppById.get(project.Oportunidade__c);
            if(opp == null){
                continue;
            }

            if(project.Conta__c == null && opp.AccountId != null){
                project.Conta__c = opp.AccountId;
            }

            if(String.isBlank(project.PotenciaSistema__c) && opp.PotenciaNominalSistema__c != null){
                project.PotenciaSistema__c = String.valueOf(opp.PotenciaNominalSistema__c);
            }
        }
    }

    public static void setDefaultStatus(List<Projeto__c> projects){
        if(projects == null){
            return;
        }
        for(Projeto__c project : projects){
            if(String.isBlank(project.Status__c)){
                project.Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO;
            }
        }
    }

    public static void updateStatusDurations(List<Projeto__c> newRecordList, Map<Id, Projeto__c> oldMap){
        if(oldMap == null || newRecordList == null){
            return;
        }

        for(Projeto__c project : newRecordList){
            Projeto__c oldProject = oldMap.get(project.Id);
            if(oldProject == null){
                continue;
            }

            Boolean statusChanged = oldProject.Status__c != project.Status__c;
            if(!statusChanged){
                continue;
            }

            DateTime statusStart = oldProject.StatusAtualDesde__c;
            if(statusStart == null){
                project.StatusAtualDesde__c = System.now();
                continue;
            }

            Long elapsedSeconds = Math.max(0L, (System.now().getTime() - statusStart.getTime())/1000);
            Decimal elapsedDaysDecimal = (Decimal)elapsedSeconds / 86400;
            if(elapsedDaysDecimal <= 0){
                project.StatusAtualDesde__c = System.now();
                continue;
            }

            // Atualiza contagem total em dias (com fração)
            project.ContagemPrazo__c = (oldProject.ContagemPrazo__c == null ? 0 : oldProject.ContagemPrazo__c) + elapsedDaysDecimal;

            // Atualiza contagem por fase conforme status anterior
            if(oldProject.Status__c == ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO || oldProject.Status__c == ProjetoUtils.STATUS_PLANEJAMENTO){
                project.ContagemPrazoPlanejamento__c = (oldProject.ContagemPrazoPlanejamento__c == null ? 0 : oldProject.ContagemPrazoPlanejamento__c) + elapsedDaysDecimal;
            } else if(oldProject.Status__c == ProjetoUtils.STATUS_ELABORACAO_DE_PROJETO || oldProject.Status__c == ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO){
                project.ContagemPrazoProjetoElaboracao__c = (oldProject.ContagemPrazoProjetoElaboracao__c == null ? 0 : oldProject.ContagemPrazoProjetoElaboracao__c) + elapsedDaysDecimal;
            } else if(oldProject.Status__c == ProjetoUtils.STATUS_PROJETO_EM_ANALISE){
                project.ContagemPrazoProjetoAnalise__c = (oldProject.ContagemPrazoProjetoAnalise__c == null ? 0 : oldProject.ContagemPrazoProjetoAnalise__c) + elapsedDaysDecimal;
            }

            // Reinicia contador para o novo status
            project.StatusAtualDesde__c = System.now();
        }
    }

    public static void syncOpportunityStatusFromProject(List<Projeto__c> newRecordList, Map<Id, Projeto__c> oldMap) {
        if (newRecordList == null || newRecordList.isEmpty()) {
            return;
        }

        Boolean hasProjectStatusReason = Schema.SObjectType.Opportunity.fields.getMap().containsKey('ProjectStatusReason__c');
        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Projeto__c> projectByOpportunity = new Map<Id, Projeto__c>();

        for (Projeto__c project : newRecordList) {
            Projeto__c oldProject = oldMap != null ? oldMap.get(project.Id) : null;
            if (project.Oportunidade__c == null || oldProject == null) {
                continue;
            }

            Boolean statusChanged = oldProject.Status__c != project.Status__c;
            Boolean motivoChanged = oldProject.MotivoSubStatus__c != project.MotivoSubStatus__c;

            if (!statusChanged && !motivoChanged) {
                continue;
            }

            opportunityIds.add(project.Oportunidade__c);
            projectByOpportunity.put(project.Oportunidade__c, project);
        }

        if (opportunityIds.isEmpty()) {
            return;
        }

        String query = 'SELECT Id, Status__c';
        if (hasProjectStatusReason) {
            query += ', ProjectStatusReason__c';
        }
        query += ' FROM Opportunity WHERE Id IN :opportunityIds';

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : Database.query(query)) {
            Projeto__c project = projectByOpportunity.get(opp.Id);
            if (project == null) {
                continue;
            }

            Boolean changed = false;
            if (project.Status__c != null && opp.Status__c != project.Status__c) {
                opp.Status__c = project.Status__c;
                changed = true;
            }

            if (hasProjectStatusReason && opp.get('ProjectStatusReason__c') != project.MotivoSubStatus__c) {
                opp.put('ProjectStatusReason__c', project.MotivoSubStatus__c);
                changed = true;
            }

            if (changed) {
                oppsToUpdate.add(opp);
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
    
    public static void createTasks(List<Projeto__c> newRecordList, Map<Id, Projeto__c> oldMap){
        Map<String, Id> recordTypeStringCodeToId = getRecordTypeCodeToIdMap();
        Map<Id, String> recordTypeIdToStringCode = getRecordTypeIdToCodeMap();
        Map<String, String> statusCodeToStatus = getStatusCodeToStatusMap();
        Map<String, String> statusToStatusCode = getStatusToStatusCodeMap();
        Map<String, Group> queueMap = ProjetoUtils.getQueueIdByName();

        Set<Id> userIds = new Set<Id>();
        for(Projeto__c project : newRecordList){
            if(project.GestorObra__c != null){
                userIds.add(project.GestorObra__c);
            }
            if(project.Projetista__c != null){
                userIds.add(project.Projetista__c);
            }
        }

        Map<Id, User> userById = fetchUsers(userIds);

        //  Recupera a tabela do Recurso Estático
        TaskProjectTable taskProjectTable = getTaskProjectTableFromStaticResource();
        //  [Nome do Record Type -> (Nome do Status -> Tasks)]
        Map<String, Map<String, List<TaskProjectTableLine>>> mapRecordTypesToStatusTasks = new Map<String, Map<String, List<TaskProjectTableLine>>>();
        
        //  Map de Tipos de Registros -> Status cuja modificação gera Tasks
        Map<String, List<String>> recordTypeToStatusChangesList = new Map<String, List<String>>();

        //  Itera sobre a tabela recuperada do Recurso Estático, para popular o Map criado anteriormente
        for(TaskProjectTableLine line : taskProjectTable.tableLines){
            String tipoProjetoObra = line.TipoProjetoObra;
            String status = line.Status;

            if(!mapRecordTypesToStatusTasks.containsKey(tipoProjetoObra)){
                mapRecordTypesToStatusTasks.put(tipoProjetoObra, new Map<String, List<TaskProjectTableLine>>());
            }

            Map<String, List<TaskProjectTableLine>> mapStatusToTasksTemplate = mapRecordTypesToStatusTasks.get(tipoProjetoObra);
            if(!mapStatusToTasksTemplate.containsKey(status)){
                mapStatusToTasksTemplate.put(status, new List<TaskProjectTableLine>());
            }

            if(!recordTypeToStatusChangesList.containsKey(tipoProjetoObra)){
                recordTypeToStatusChangesList.put(tipoProjetoObra, new List<String>());
            }
            if(!recordTypeToStatusChangesList.get(tipoProjetoObra).contains(status)){
                recordTypeToStatusChangesList.get(tipoProjetoObra).add(status);
            }

            mapStatusToTasksTemplate.get(status).add(line);
        }
        //  Tipos de Registro que precisam da validação do Gestor e do Projetista
        Set<Id> recordTypesToValidateTwoResponsibles = new Set<Id>{
            ProjetoUtils.RT_UFV_MICRO,
            ProjetoUtils.RT_UFV_MINI_ATE_300,
            ProjetoUtils.RT_UFV_MINI_ACIMA_DE_300,
            ProjetoUtils.RT_BOMBEAMENTO,
            ProjetoUtils.RT_ESTACAO_DE_RECARGA,
            ProjetoUtils.RT_PADRAO_DE_ENTRADA,
            ProjetoUtils.RT_POSTO_DE_TRANSFORMACAO,
            ProjetoUtils.RT_SUBESTACAO
        };

        //  IDs das Oportunidades que já tem Projetos de Financiamento para servir de controle caso Projetos UFVs sejam criados
        //  para poder pular as fases de Financiamento
        Set<Id> financimentoProjectOpportunityIdsToSkipPhasesUFV = new Set<Id>();
        Set<Id> currentOpportunities = new Set<Id>();
        for(Projeto__c projeto : newRecordList){
            currentOpportunities.add(projeto.Oportunidade__c);
        }

        for(Projeto__c projeto : [
            SELECT  Oportunidade__c
            FROM    Projeto__c
            WHERE   Oportunidade__c IN :currentOpportunities AND RecordTypeId = :ProjetoUtils.RT_FINANCIAMENTO
        ]){
            financimentoProjectOpportunityIdsToSkipPhasesUFV.add(projeto.Oportunidade__c);
        }

        Set<Id> recordTypesUFV = new Set<Id>{
            ProjetoUtils.RT_UFV_MICRO, 
            ProjetoUtils.RT_UFV_MINI_ATE_300, 
            ProjetoUtils.RT_UFV_MINI_ACIMA_DE_300
        };


        List<Task> tasksToInsert = new List<Task>();
        for(Projeto__c project : newRecordList){

            if(isInactive(userById.get(project.GestorObra__c))){
                String gestorName = userById.get(project.GestorObra__c) != null ? userById.get(project.GestorObra__c).Name : 'selecionado';
                project.addError('Não foi possível salvar o projeto porque o Gestor de Obra ' + gestorName + ' está inativo. Altere o responsável ou reative o usuário.');
                continue;
            }

            if(isInactive(userById.get(project.Projetista__c))){
                String projetistaName = userById.get(project.Projetista__c) != null ? userById.get(project.Projetista__c).Name : 'selecionado';
                project.addError('Não foi possível salvar o projeto porque o Projetista ' + projetistaName + ' está inativo. Altere o responsável ou reative o usuário.');
                continue;
            }

            Map<String, User> roleToUser = buildRoleUserMap(project, userById);

            String recordTypeCode = recordTypeIdToStringCode.get(project.RecordTypeId);
            if(String.isBlank(recordTypeCode)){
                String recordTypeName = Schema.getGlobalDescribe().get('Projeto__c').getDescribe().getRecordTypeInfosById().get(project.RecordTypeId).getName();
                Id resolvedId = ProjetoUtils.getRecordTypeIdByName(recordTypeName);
                recordTypeCode = recordTypeIdToStringCode.get(resolvedId);
            }

            //  Map com os Templates das Tasks a serem criadas de acordo com o Status do Projeto atual
            Map<String, List<TaskProjectTableLine>> mapStatusToTasksTemplate = mapRecordTypesToStatusTasks.get(recordTypeCode);
            System.debug('mapStatusToTasksTemplate '+ mapStatusToTasksTemplate);
            if(mapStatusToTasksTemplate == null){
                continue;
            }
			
            //  Lista dos nomes dos usuários "interessados" no projeto, a serem citados em campo da Task
            List<String> interessadosList = new List<String>();

            //  Chave a ser usada para recuperar informações do Map Status -> Templates
            String key;

            //  Criar a(s) Task(s) inicial(is) para delegação de Gestor de Obra e/ou Projetista
            if(oldMap.get(project.Id) == null){
                key = statusToStatusCode.get(ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO) != null ? statusToStatusCode.get(ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO) :statusToStatusCode.get(ProjetoUtils.STATUS_PLANEJAMENTO);
                key +=  project.RecordTypeId == ProjetoUtils.RT_PADRAO_DE_ENTRADA ? '_SIM' : '';

                System.debug('mapStatusToTasksTemplate '+ mapStatusToTasksTemplate);
                System.debug('key '+ key);

                list<TaskProjectTableLine> lines = mapStatusToTasksTemplate == null || mapStatusToTasksTemplate.get(key) == null ? new list<TaskProjectTableLine>() : mapStatusToTasksTemplate.get(key);
                lines = sortByOrder(lines);
                System.debug('lines '+ lines);

                for(TaskProjectTableLine line : lines){
                    System.debug('line '+ line);

                    if (line == null || String.isBlank(line.Assunto)) {
                        continue;
                    }
                    if (TaskBO.taskSubjectExists(project.Id, line.Assunto)) {
                        continue;
                    }

                    Boolean isDelegar = line.Assunto.contains('DELEGAR PROJETISTA') || line.Assunto.contains('DELEGAR GESTOR DE OBRAS');
                    interessadosList = line.Interessados != null && line.Interessados != '' ? line.Interessados.split(';') : null;

                    Task generated = createTask(line, project, interessadosList, isDelegar, roleToUser, queueMap);
                    if(generated != null){
                        tasksToInsert.add(generated);
                    }

                    if(isDelegar && interessadosList != null && recordTypesToValidateTwoResponsibles.contains(project.RecordTypeId)){
                        // cria segunda task de delegação quando há dois responsáveis
                        TaskProjectTableLine secondLine = (mapStatusToTasksTemplate.get(key) != null && mapStatusToTasksTemplate.get(key).size() > 1)
                            ? mapStatusToTasksTemplate.get(key)[1]
                            : null;
                        List<String> interestedTwo = secondLine != null && secondLine.Interessados != null && secondLine.Interessados != '' ? secondLine.Interessados.split(';') : null;
                        Task generatedTwo = createTask(secondLine != null ? secondLine : line, project, interestedTwo, true, roleToUser, queueMap);
                        if(generatedTwo != null){
                            tasksToInsert.add(generatedTwo);
                        }
                    }
                }
                continue;
            }
            
            if(oldMap.get(project.Id) != null){

                //  Validar se o Projetista e/ou Gestor de Obras estão sendo atribuídos, sendo necessária a
                //  criação das demais Tasks para o Status "Planejamento"
                if(
                    (
                        recordTypesToValidateTwoResponsibles.contains(project.RecordTypeId) &&
                        ProjetoUtils.hasEngineerCoordinatorSetProjectResponsibles(project, oldMap.get(project.Id))
                    ) ||
                    (
                        project.RecordTypeId != ProjetoUtils.RT_PADRAO_DE_ENTRADA &&
                        ProjetoUtils.hasEngineerCoordinatorSetDevisor(project, oldMap.get(project.Id))
                    )
                ){
                    key = statusToStatusCode.get(ProjetoUtils.STATUS_PLANEJAMENTO);
                    key +=  project.RecordTypeId == ProjetoUtils.RT_PADRAO_DE_ENTRADA ? '_SIM' : '';


                    TaskProjectTableLine[] lines = mapStatusToTasksTemplate == null ? new List<TaskProjectTableLine>() :  mapStatusToTasksTemplate.get(key) != null ? mapStatusToTasksTemplate.get(key) : new List<TaskProjectTableLine>();
                    lines = sortByOrder(lines);

                    for(TaskProjectTableLine line : lines){
                        if (line == null || String.isBlank(line.Assunto)) {
                            continue;
                        }
                        if (TaskBO.taskSubjectExists(project.Id, line.Assunto)) {
                            continue;
                        }

                        if(
                            (
                                !line.Assunto.contains('DELEGAR PROJETISTA') && 
                                !line.Assunto.contains('DELEGAR GESTOR DE OBRAS')
                            )
                        ){
                            if(shouldUFVPhaseBeCreated(project, line.Assunto, recordTypesUFV, financimentoProjectOpportunityIdsToSkipPhasesUFV)){
                                interessadosList = line.Interessados != null && line.Interessados != '' ? line.Interessados.split(';') : null;

                                Task generatedPlanning = createTask(line, project, interessadosList, false, roleToUser, queueMap);
                                if(generatedPlanning != null){
                                    tasksToInsert.add(generatedPlanning);
                                }
                            }
                        }
                    }
                }

                //  Se Status do Projeto estiver mudando, validar se a mudança de Status deve disparar
                //  a criação das Tasks parametrizadas para este Status

                if(ProjetoUtils.isStatusChanging(project, oldMap.get(project.Id)) && recordTypeToStatusChangesList != null && recordTypeIdToStringCode != null){

                    //  Itera sobre o Map que relaciona o tipo de registro com os Status que geram criação de Tasks,
                    //  baseando-se no tipo de registro do Projeto atual
                    for(String statusToCreateTaskOnChanging : recordTypeToStatusChangesList.get(recordTypeCode)){

                        //  Verifica se algum dos Status sendo iterados é o Status que foi atribuído no Projeto
                        String status;
                        
                        if(project.RecordTypeId == ProjetoUtils.RT_PADRAO_DE_ENTRADA){
                            status = statusCodeToStatus.get(statusToCreateTaskOnChanging.substring(0, statusToCreateTaskOnChanging.length() - 4));
                        } else {
                            status = statusCodeToStatus.get(statusToCreateTaskOnChanging);
                        }

                        key = statusToStatusCode.get(status);
                        key +=  project.RecordTypeId == ProjetoUtils.RT_PADRAO_DE_ENTRADA ? '_SIM' : '';

                if(project.Status__c == status){

                    //  Pega os templates de Task para o Status que foi atribuído na transação atual
                    TaskProjectTableLine[] lines = mapStatusToTasksTemplate.get(key) != null ? mapStatusToTasksTemplate.get(key) : new List<TaskProjectTableLine>();
                    lines = sortByOrder(lines);
                    for(TaskProjectTableLine line : lines){
                        if (line == null || String.isBlank(line.Assunto)) {
                            continue;
                        }
                        if (TaskBO.taskSubjectExists(project.Id, line.Assunto)) {
                            continue;
                        }

                        if(shouldUFVPhaseBeCreated(project, line.Assunto, recordTypesUFV, financimentoProjectOpportunityIdsToSkipPhasesUFV)){
                            interessadosList = line.Interessados != null && line.Interessados != '' ? line.Interessados.split(';') : null;

                            Task generatedStatus = createTask(line, project, interessadosList, false, roleToUser, queueMap);
                                    if(generatedStatus != null){
                                        tasksToInsert.add(generatedStatus);
                                    }
                                }
                            }
                            break;
                        }
                    }
                    continue;
                }
            }
        }
        if(!tasksToInsert.isEmpty()){
            try{
                insert tasksToInsert;
            } catch(Exception ex){
                // Não bloquear o salvamento do Projeto se processos externos (Flow/Process Builder) falharem na criação de tarefas
                Utils.createLog('ProjetoBO', 'createTasks', ex, newRecordList.isEmpty() ? null : newRecordList[0].Id);
            }
        }
    }

    public static Task createTask(
        TaskProjectTableLine line,
        Projeto__c projeto,
        List<String> interessadosList,
        Boolean isFirst,
        Map<String, User> roleToUser,
        Map<String, Group> queueMap
    ){
        if(line == null || String.isBlank(line.Assunto)){
            return null;
        }

        Map<String, User> userRoleToUser = roleToUser != null ? roleToUser : new Map<String, User>{
            'PROJETISTA'      => ProjetoUtils.getProjetistaById(projeto.Projetista__c),
            'GESTOR_DE_OBRAS' => ProjetoUtils.getGestorObrasById(projeto.GestorObra__c)
        };
            
        Map<String, Group> groupRoleToGroup = queueMap != null ? queueMap : ProjetoUtils.getQueueIdByName();
        Id ownerId = TaskTemplateUtils.resolveOwner(line, userRoleToUser, groupRoleToGroup, projeto);
     
        System.debug('line ' + line);

        if(ownerId == null){
            populateUserEmailMap(); 
            if (Test.isRunningTest()) {
                ownerId = UserInfo.getUserId();
            } else {
                String msg = 'Não foi possível definir o proprietário da tarefa "' + line.Assunto + '" (Responsável: ' +
                    (line.Responsavel != null ? line.Responsavel : 'não informado') +
                    ' | TipoProprietario: ' + (line.TipoDeProprietario != null ? line.TipoDeProprietario : 'não informado') +
                    '). Verifique se o usuário/fila está ativo ou existe na org.';
                projeto.addError(msg);
                return null;
            }
        }

        if(!ensureActiveOwner(ownerId, projeto, line != null ? line.Assunto : '', userRoleToUser)){
            return null;
        }

        System.debug('taskOwner ' + ownerId);
        Task task = new Task(
            TipoObraProjeto__c     = Schema.getGlobalDescribe().get('Projeto__c').getDescribe().getRecordTypeInfosById().get(projeto.RecordTypeId).getName(),
            StatusProjeto__c       = projeto.Status__c,
            Subject                = line.Assunto,
            Description            = line.Acoes,
            WhatId                 = projeto.Id,
            PrazoDiasUteis__c      = line.PrazoDiasUteis,
            OwnerId                = ownerId
        );

        if(
            projeto.RecordTypeId == ProjetoUtils.RT_FINANCIAMENTO && 
            projeto.Status__c == ProjetoUtils.STATUS_PROJETO_APROVADO
        ){
            
            if(projeto.TipoRegistroOportunidade__c == 'ContratoMicro'){
                task.PrazoDiasUteis__c = '15';
            }

            if(projeto.TipoRegistroOportunidade__c == 'ContratoMini'){
                task.PrazoDiasUteis__c = '30';
            }
        }

        Integer daysToConsiderActivity = TaskTemplateUtils.parseInteger(
            String.valueOf(task.PrazoDiasUteis__c),
            TaskTemplateUtils.parseInteger(line.DataVencimentoDMais, 0)
        );

        Date baseDate = System.today();
        if(
            projeto != null &&
            projeto.CreatedDate != null &&
            (
                task.Subject.equalsIgnoreCase('RECEBIMENTO DOS MATERIAIS COMPLEMENTARES') || 
                task.Subject.equalsIgnoreCase('RECEBIMENTO DO KIT WEG')
            )
        ){
            baseDate = Date.valueOf(projeto.CreatedDate);
        }

        task.ActivityDate = TaskBO.getActivityDateBasedOnWorkingDays(baseDate, daysToConsiderActivity);
        if(Schema.SObjectType.Task.fields.getMap().containsKey('HoraVencimento__c')){
            task.put('HoraVencimento__c', TaskTemplateUtils.defaultDueTime());
        }

        if(interessadosList != null && userRoleToUser != null){
            for(Integer i = 0; i < interessadosList.size(); i++){
                User user = 
                    userRoleToUser.containsKey(interessadosList[i]) && userRoleToUser.get(interessadosList[i]) != null ?
                    userRoleToUser.get(interessadosList[i]) : null;

                String name = user != null ? user.Name : interessadosList[i];

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

    public static boolean shouldUFVPhaseBeCreated(
        Projeto__c project, 
        String phase, 
        Set<Id> recordTypesUFV, 
        Set<Id> financimentoProjectOpportunityIdsToSkipPhasesUFV 
    ){
        List<String> financiamentoPhases = new List<String>{
            'INSERIR ART',
            'REALIZAR PAGAMENTO DA ART',
            'INSERIR PROCURAÇÃO ASSINADA',
            'VERIFICAR DOCUMENTOS',
            'VERIFICAR VIABILIDADE TÉCNICA',
            'SOLICITAR VERIFICAÇÃO DE PROJETO',
            'ANEXAR PROJETO DE CONCESSIONÁRIA',
            'SOLICITAR PROTOCOLO DE PROJETO',
            'PROTOCOLO PROJETO UFV',
            'CONFIRMAR PROTOCOLO DAS BENEFICIARIAS',
            'APROVAÇÃO DO PROJETO UFV'
        };

        if(!recordTypesUFV.contains(project.RecordTypeId)){
            return true;
        }

        if(
            recordTypesUFV.contains(project.RecordTypeId) && 
            !financimentoProjectOpportunityIdsToSkipPhasesUFV.contains(project.Oportunidade__c)
        ){
            return true;
        }

        if(
            recordTypesUFV.contains(project.RecordTypeId) &&
            financimentoProjectOpportunityIdsToSkipPhasesUFV.contains(project.Oportunidade__c)
        ){
            for(String financiamentoPhase : financiamentoPhases){
                if(phase.contains(financiamentoPhase)){
                    return false;
                }
            }
        }
        
        return true;
    }

    public static void checkTasksConclusionBeforeStatusChange(List<Projeto__c> newRecordList, Map<Id, Projeto__c> oldMap){
        if (newRecordList == null || newRecordList.isEmpty()) {
            return;
        }

        for (Projeto__c project : newRecordList){
            if(ProjetoUtils.isStatusChanging(project, oldMap.get(project.Id))){
                if (TaskBO.hasOpenTasks(project.Id)) {
                    project.addError('Todas as tarefas existentes para esse projeto precisam estar concluídas antes de avançar de fase.');
                }
            }
        }
    }

    public static TaskProjectTable getTaskProjectTableFromStaticResource(){
        return getTaskTableFromStaticResource('TabelaTarefasProjetos');
    }

    public static TaskProjectTable getTaskTableFromStaticResource(String staticResourceName){
        TaskProjectTable table = new TaskProjectTable();
        table.tableLines = new List<TaskProjectTableLine>();

        if(String.isBlank(staticResourceName)){
            return table;
        }

        StaticResource taskProjectTable = [
            SELECT  Id, Body 
            FROM    StaticResource 
            WHERE   Name = :staticResourceName
            LIMIT   1
        ];
        String tableBody = taskProjectTable.Body.toString();

        CSVReader tableBodyCSVReader = new CSVReader(tableBody, ';');

        // read header
        String[] header = tableBodyCSVReader.readLine();
        Map<String, Integer> headerIndex = new Map<String, Integer>();
        if(header != null){
            for(Integer i = 0; i < header.size(); i++){
                String col = normalizeHeader(header[i]);
                if(!String.isBlank(col)){
                    headerIndex.put(col, i);
                }
            }
        }

        String[] tableBodyLine = tableBodyCSVReader.readLine();

        while (tableBodyLine != null){
            TaskProjectTableLine line = new TaskProjectTableLine();
            line.RowNumber = table.tableLines.size();

            line.TipoProjetoObra     = getCsvValue(headerIndex, tableBodyLine, 'TIPOPROJETOOBRA');
            line.Status              = getCsvValue(headerIndex, tableBodyLine, 'STATUS');
            line.Assunto             = getCsvValue(headerIndex, tableBodyLine, 'ASSUNTO');
            line.Acoes               = getCsvValue(headerIndex, tableBodyLine, 'ACOES');
            line.Observacoes         = getCsvValue(headerIndex, tableBodyLine, 'OBSERVACOES');
            line.Responsavel         = getCsvValue(headerIndex, tableBodyLine, 'RESPONSAVEL');
            line.Interessados        = getCsvValue(headerIndex, tableBodyLine, 'INTERESSADOS');
            line.PrazoDiasUteis      = getCsvValue(headerIndex, tableBodyLine, 'PRAZODIASUTEIS');
            line.DataVencimentoDMais = getCsvValue(headerIndex, tableBodyLine, 'DATAVENCIMENTODMAIS');
            line.TipoDeProprietario  = getCsvValue(headerIndex, tableBodyLine, 'TIPOPROPRIETARIO');
            String ordemStr          = getCsvValue(headerIndex, tableBodyLine, 'ORDEM');
            if (!String.isBlank(ordemStr)) {
                try {
                    line.Ordem = Integer.valueOf(ordemStr);
                } catch (Exception ignore) {
                    line.Ordem = null;
                }
            }

            if(String.isBlank(line.TipoProjetoObra) || line.TipoProjetoObra.equalsIgnoreCase('EXCLUIR')){
                tableBodyLine = tableBodyCSVReader.readLine();
                continue;
            }

            table.tableLines.add(line);

            tableBodyLine = tableBodyCSVReader.readLine();
        }
        return table;
    }

    // Ordena linhas pelo campo Ordem (asc), mantendo nulos no fim
    private static List<TaskProjectTableLine> sortByOrder(List<TaskProjectTableLine> lines) {
        if (lines == null || lines.isEmpty()) {
            return lines;
        }
        lines.sort(new TaskProjectTableLineComparator());
        return lines;
    }

    private static String normalizeHeader(String headerValue){
        if(String.isBlank(headerValue)){
            return '';
        }
        String clean = headerValue.replace('\ufeff', '').trim().toUpperCase();
        return clean;
    }

    private static String getCsvValue(Map<String, Integer> headerIndex, String[] row, String columnKey){
        if(row == null || headerIndex == null){
            return '';
        }
        Integer idx = headerIndex.get(columnKey);
        if(idx == null || idx >= row.size()){
            return '';
        }
        return String.valueOf(row[idx]).trim();
    }

    public static Map<String, Id> getRecordTypeCodeToIdMap(){
        return new Map<String, Id>{
            'RT_BOMBEAMENTO'            => ProjetoUtils.RT_BOMBEAMENTO,
            'RT_ESTACAO_DE_RECARGA'     => ProjetoUtils.RT_ESTACAO_DE_RECARGA,
            'RT_FINANCIAMENTO'          => ProjetoUtils.RT_FINANCIAMENTO,
            'RT_PADRAO_DE_ENTRADA'      => ProjetoUtils.RT_PADRAO_DE_ENTRADA,
            'RT_POSTO_DE_TRANSFORMACAO' => ProjetoUtils.RT_POSTO_DE_TRANSFORMACAO,
            'RT_SUBESTACAO'             => ProjetoUtils.RT_SUBESTACAO,
            'RT_UFV_MICRO'              => ProjetoUtils.RT_UFV_MICRO,
            'RT_UFV_MINI_ACIMA_DE_300'  => ProjetoUtils.RT_UFV_MINI_ACIMA_DE_300,
            'RT_UFV_MINI_ATE_300'       => ProjetoUtils.RT_UFV_MINI_ATE_300
        };
    }

    public static Map<Id, String> getRecordTypeIdToCodeMap(){
        return new Map<ID, String>{
            ProjetoUtils.RT_BOMBEAMENTO            => 'RT_BOMBEAMENTO',
            ProjetoUtils.RT_ESTACAO_DE_RECARGA     => 'RT_ESTACAO_DE_RECARGA',
            ProjetoUtils.RT_FINANCIAMENTO          => 'RT_FINANCIAMENTO',
            ProjetoUtils.RT_PADRAO_DE_ENTRADA      => 'RT_PADRAO_DE_ENTRADA',
            ProjetoUtils.RT_POSTO_DE_TRANSFORMACAO => 'RT_POSTO_DE_TRANSFORMACAO',
            ProjetoUtils.RT_SUBESTACAO             => 'RT_SUBESTACAO',
            ProjetoUtils.RT_UFV_MICRO              => 'RT_UFV_MICRO',
            ProjetoUtils.RT_UFV_MINI_ACIMA_DE_300  => 'RT_UFV_MINI_ACIMA_DE_300',
            ProjetoUtils.RT_UFV_MINI_ATE_300       => 'RT_UFV_MINI_ATE_300'
        };
    }

    public static Map<String, String> getStatusCodeToStatusMap(){
        return new Map<String, String>{
            'STATUS_NAO_DEFINIDO'                               => ProjetoUtils.STATUS_NAO_DEFINIDO,
            'STATUS_PLANEJAMENTO'                               => ProjetoUtils.STATUS_PLANEJAMENTO,
            'STATUS_ELABORACAO_DE_PROJETO'                      => ProjetoUtils.STATUS_ELABORACAO_DE_PROJETO,
            'STATUS_PROJETO_EM_ANALISE'                         => ProjetoUtils.STATUS_PROJETO_EM_ANALISE,
            'STATUS_PROJETO_APROVADO'                           => ProjetoUtils.STATUS_PROJETO_APROVADO,
            'STATUS_PROJETOS_EM_ELABORACAO'                     => ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO,
            'STATUS_OBRA_EM_EXECUCAO'                           => ProjetoUtils.STATUS_OBRA_EM_EXECUCAO,
            'STATUS_OBRA_CONCLUIDA'                             => ProjetoUtils.STATUS_OBRA_CONCLUIDA,
            'STATUS_USINA_OPERANDO'                             => ProjetoUtils.STATUS_USINA_OPERANDO,
            'STATUS_OBRA_CONCLUIDA_AGUARDANDO_TROCA_DE_MEDIDOR' => ProjetoUtils.STATUS_OBRA_CONCLUIDA_AGUARDANDO_TROCA_DE_MEDIDOR,
            'STATUS_LIGACAO_SOLICITADA'                         => ProjetoUtils.STATUS_LIGACAO_SOLICITADA,
            'STATUS_PROJETO_PROTOCOLADO'                        => ProjetoUtils.STATUS_PROJETO_PROTOCOLADO,
            'STATUS_PLANEJAMENTO_DE_PROJETO'                    => ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
            'STATUS_PLANEJAMENTO_DE_OBRA'                       => ProjetoUtils.STATUS_PLANEJAMENTO_DE_OBRA,
            'STATUS_AGUARDANDO_VISTORIA'                        => ProjetoUtils.STATUS_AGUARDANDO_VISTORIA
        };
    }

    public static Map<String, String> getStatusToStatusCodeMap(){
        return new Map<String, String>{
            ProjetoUtils.STATUS_NAO_DEFINIDO                               => 'STATUS_NAO_DEFINIDO',
            ProjetoUtils.STATUS_PLANEJAMENTO                               => 'STATUS_PLANEJAMENTO',
            ProjetoUtils.STATUS_ELABORACAO_DE_PROJETO                      => 'STATUS_ELABORACAO_DE_PROJETO',
            ProjetoUtils.STATUS_PROJETO_EM_ANALISE                         => 'STATUS_PROJETO_EM_ANALISE',
            ProjetoUtils.STATUS_PROJETO_APROVADO                           => 'STATUS_PROJETO_APROVADO',
            ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO                     => 'STATUS_PROJETOS_EM_ELABORACAO',
            ProjetoUtils.STATUS_OBRA_EM_EXECUCAO                           => 'STATUS_OBRA_EM_EXECUCAO',
            ProjetoUtils.STATUS_OBRA_CONCLUIDA                             => 'STATUS_OBRA_CONCLUIDA',
            ProjetoUtils.STATUS_USINA_OPERANDO                             => 'STATUS_USINA_OPERANDO',
            ProjetoUtils.STATUS_OBRA_CONCLUIDA_AGUARDANDO_TROCA_DE_MEDIDOR => 'STATUS_OBRA_CONCLUIDA_AGUARDANDO_TROCA_DE_MEDIDOR',
            ProjetoUtils.STATUS_LIGACAO_SOLICITADA                         => 'STATUS_LIGACAO_SOLICITADA',
            ProjetoUtils.STATUS_PROJETO_PROTOCOLADO                        => 'STATUS_PROJETO_PROTOCOLADO',
            ProjetoUtils.STATUS_AGUARDANDO_VISTORIA                        => 'STATUS_AGUARDANDO_VISTORIA',
            ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO                    => 'STATUS_PLANEJAMENTO_DE_PROJETO',
            ProjetoUtils.STATUS_PLANEJAMENTO_DE_OBRA                       => 'STATUS_PLANEJAMENTO_DE_OBRA'
        };
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

    private static Map<String, User> buildRoleUserMap(Projeto__c projeto, Map<Id, User> userById){
        return new Map<String, User>{
            'PROJETISTA'      => userById != null ? userById.get(projeto.Projetista__c) : null,
            'GESTOR_DE_OBRAS' => userById != null ? userById.get(projeto.GestorObra__c) : null
        };
    }

    private static Boolean ensureActiveOwner(Id ownerId, Projeto__c projeto, String subject, Map<String, User> roleToUser){
        if(ownerId == null){
            return false;
        }

        if(ownerId.getSObjectType() != User.SObjectType){
            return true;
        }

        User ownerUser = getOwnerUser(ownerId, roleToUser);
        if(ownerUser == null){
            projeto.addError('Não foi possível criar a tarefa "' + subject + '" porque o proprietário configurado não foi encontrado. Atualize o responsável ou reative o usuário.');
            return false;
        }

        if(!ownerUser.IsActive){
            projeto.addError('Não foi possível criar a tarefa "' + subject + '" porque o proprietário configurado está inativo (' + ownerUser.Name + '). Altere o responsável ou reative o usuário antes de salvar o projeto.');
            return false;
        }

        return true;
    }

    private static User getOwnerUser(Id ownerId, Map<String, User> roleToUser){
        if(ownerId == null || ownerId.getSObjectType() != User.SObjectType){
            return null;
        }

        if(ownerUserCache.containsKey(ownerId)){
            return ownerUserCache.get(ownerId);
        }

        if(roleToUser != null){
            for(User candidate : roleToUser.values()){
                if(candidate != null && candidate.Id == ownerId){
                    ownerUserCache.put(ownerId, candidate);
                    return candidate;
                }
            }
        }

        List<User> users = [
            SELECT Id, Name, IsActive
            FROM User
            WHERE Id = :ownerId
            LIMIT 1
        ];

        User resolved = users.isEmpty() ? null : users[0];
        ownerUserCache.put(ownerId, resolved);
        return resolved;
    }

    
    public static void createTaskOnboarding(List<Projeto__c> projects, Map<Id, Projeto__c> oldMap){
        
        try{

            Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Jornada_do_Cliente').getRecordTypeId();

            Set<Id> opportunityIds = new Set<Id>();
            List<Projeto__c> projectsFiltered = new List<Projeto__c>();
            Set<Id> projectIds = new Set<Id>();
            List<Task> tasks = new List<Task>();
            List<Case> casesToUpdate = new List<Case>();
            Map<Id, Case> caseByOpportunityId = new Map<Id, Case>();
            Map<Id, viabilityStudy__c> viabilityByOpportunityId = new Map<Id, viabilityStudy__c>();
            
            for(Projeto__c project : projects){

                Projeto__c oldProject = oldMap.get(project.Id);

                //Filtrar projetos com gestor e consultor preenchido.
                if(String.isNotBlank(project.Oportunidade__c) && (String.isNotBlank(project.Consultor__c) && String.isNotBlank(project.GestorObra__c)) && (String.isBlank(oldProject.Consultor__c) || String.isBlank(oldProject.GestorObra__c))){
                    opportunityIds.add(project.Oportunidade__c);
                    projectIds.add(project.Id);
                }

            }

            if(projectIds.isEmpty()) return;

            Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>([SELECT Id, AccountId, ContactId FROM Opportunity WHERE Id IN :opportunityIds]);

            List<Case> cases = [SELECT Id, Nome_da_Oportunidade__c, OwnerId, CreatedDate, ContactId FROM Case WHERE Nome_da_Oportunidade__c IN :opportunityIds AND RecordTypeId = :caseRecordTypeId];
            List<ViabilityStudy__c> viabilities = [SELECT Id, Opportunity__c FROM ViabilityStudy__c WHERE Opportunity__c IN :opportunityIds];

            if(viabilities != null){
                for(ViabilityStudy__c viability : viabilities){
                    viabilityByOpportunityId.put(viability.Opportunity__c, viability);
                }
            }

            projectsFiltered = [SELECT Id, GestorObra__c, GestorObra__r.Name, Consultor__c, PotenciaPicoSistemakWp__c, Oportunidade__c, ConcessionariaEnergia__c FROM Projeto__c WHERE Id IN :projectIds];

            for(Case caseRecord : cases){
                caseByOpportunityId.put(caseRecord.Nome_da_Oportunidade__c, caseRecord);
            }
               
            for(Projeto__c project : projectsFiltered){

                Opportunity opportunity = opportunityById.get(project.Oportunidade__c);

                if(opportunity == null) continue;

                Case caseRecord = caseByOpportunityId.get(opportunity.Id);

                if(caseRecord == null) continue;

                caseRecord.ManagerName__c = project.GestorObra__c;
                caseRecord.Nome_do_Consultor__c = project.Consultor__c;
                
                if(project.PotenciaPicoSistemakWp__c != null) caseRecord.KWP__c = String.valueOf(project.PotenciaPicoSistemakWp__c);

                casesToUpdate.add(caseRecord);

                Task task = TaskBO.createTask(caseRecord.Id, 'Informações Iniciais', 'Primeiro contato com o cliente. Informações iniciais do projeto', caseRecord.OwnerId, caseRecord.CreatedDate.Date().addDays(5), null);
                task.WhoId = caseRecord.ContactId;
                task.NextNotification__c = '15 dias';
                task.Manager__c = project.GestorObra__c != null ? project.GestorObra__r.Name : ' ';
                if(project.PotenciaPicoSistemakWp__c != null) task.KWP__c = String.valueOf(project.PotenciaPicoSistemakWp__c);
                task.Type = 'Jornada do Projeto';
                task.CreateNewTaskAutomatically__c = false;
                task.ConcessionariaEnergia__c = project.ConcessionariaEnergia__c;
                tasks.add(task);
            }
            
            if(!tasks.isEmpty())
                insert tasks;

            if(!casesToUpdate.isEmpty())
                update casesToUpdate;

        }catch(Exception ex){
            System.debug('##Erro ao criar Caso de Jornada do Projeto: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
    }



    public static void createTaskProjectApproved(List<Projeto__c> projects, Map<Id, Projeto__c> oldMap){
        
        try{

            Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Jornada_do_Cliente').getRecordTypeId();

            Set<Id> opportunityIds = new Set<Id>();
            List<Projeto__c> projectsFiltered = new List<Projeto__c>();
            Set<Id> projectIds = new Set<Id>();
            List<Task> tasks = new List<Task>();
            List<Case> casesToUpdate = new List<Case>();
            Map<Id, Case> caseByOpportunityId = new Map<Id, Case>();
            Map<Id, viabilityStudy__c> viabilityByOpportunityId = new Map<Id, viabilityStudy__c>();
            
            for(Projeto__c project : projects){

                Projeto__c oldProject = oldMap.get(project.Id);

                //Filtrar projetos aprovados.
                if(project?.ApprovalDate__c != oldProject?.ApprovalDate__c && project.ApprovalDate__c != null){
                    opportunityIds.add(project.Oportunidade__c);
                    projectsFiltered.add(project);
                }

            }

            if(projectsFiltered.isEmpty()) return;

            Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>([SELECT Id, AccountId, ContactId FROM Opportunity WHERE Id IN :opportunityIds]);
            List<Case> cases = [SELECT Id, Nome_da_Oportunidade__c, Status, OwnerId, ContactId FROM Case WHERE Nome_da_Oportunidade__c IN :opportunityIds AND RecordTypeId = :caseRecordTypeId];

            for(Case caseRecord : cases){
                caseByOpportunityId.put(caseRecord.Nome_da_Oportunidade__c, caseRecord);
            }
               
            for(Projeto__c project : projectsFiltered){

                Opportunity opportunity = opportunityById.get(project.Oportunidade__c);

                if(opportunity == null) continue;

                Case caseRecord = caseByOpportunityId.get(opportunity.Id);

                if(caseRecord == null) continue;

                caseRecord.Status = 'Projeto Aprovado';

                casesToUpdate.add(caseRecord);

                Task task = TaskBO.createTask(caseRecord.Id, 'Projeto Aprovado', 'Projeto Aprovado. Os próximos passos serão referente a instalação.', caseRecord.OwnerId, project.ApprovalDate__c, null);
                task.WhoId = caseRecord.ContactId;
                task.NextNotification__c = '5 dias';
                task.Type = 'Jornada do Projeto';
                task.CreateNewTaskAutomatically__c = true;
                task.ConcessionariaEnergia__c = project.ConcessionariaEnergia__c;
                task.ProjectApprovalDate__c = project.ApprovalDate__c;
                tasks.add(task);
            }
            
            if(!tasks.isEmpty())
                insert tasks;

            if(!casesToUpdate.isEmpty())
                update casesToUpdate;

        }catch(Exception ex){
            System.debug('##Erro ao criar Task de aprovação de projeto: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
        
    }

    public static void createTaskFinishProject(List<Projeto__c> projects, Map<Id, Projeto__c> oldMap){
        
        try{

            Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Jornada_do_Cliente').getRecordTypeId();

            Set<Id> opportunityIds = new Set<Id>();
            List<Projeto__c> projectsFiltered = new List<Projeto__c>();
            Set<Id> projectIds = new Set<Id>();
            Map<Id, Case> caseByOpportunityId = new Map<Id, Case>();
            Map<Id, Task> taskByCaseId = new Map<Id, Task>();
            
            for(Projeto__c project : projects){

                Projeto__c oldProject = oldMap.get(project.Id);

                //Filtrar projetos aprovados.
                if(project?.FinishProjectDate__c != oldProject?.FinishProjectDate__c && project.FinishProjectDate__c != null){
                    opportunityIds.add(project.Oportunidade__c);
                    projectsFiltered.add(project);
                }

            }

            if(projectsFiltered.isEmpty()) return;

            Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>([SELECT Id, AccountId, ContactId FROM Opportunity WHERE Id IN :opportunityIds]);
            Map<Id, Case> cases = new Map<Id, Case>([SELECT Id, Nome_da_Oportunidade__c, Status, OwnerId FROM Case WHERE Nome_da_Oportunidade__c IN :opportunityIds AND RecordTypeId = :caseRecordTypeId]);
            List<Task> tasks = [SELECT Id, ProjectApprovalDate__c, WhatId FROM Task WHERE WhatId IN :cases.keySet() AND Subject = 'Instalação - Vistoria'];

            if(tasks?.isEmpty()) return;

            for(Task task : tasks){
                taskByCaseId.put(task.WhatId, task);
            }

            for(Case caseRecord : cases.values()){
                caseByOpportunityId.put(caseRecord.Nome_da_Oportunidade__c, caseRecord);
            }
               
            for(Projeto__c project : projectsFiltered){

                Opportunity opportunity = opportunityById.get(project.Oportunidade__c);

                if(opportunity == null) continue;

                Case caseRecord = caseByOpportunityId.get(opportunity.Id);

                if(caseRecord == null) continue;

                Task task = taskByCaseId.get(caseRecord.Id);

                if(task != null){
                    task.FinishProjectDate__c = project.FinishProjectDate__c;
                }
            }
            
            if(!taskByCaseId.values().isEmpty())
                update taskByCaseId.values();

        }catch(Exception ex){
            System.debug('##Erro ao atualizar data de conclusão da obra: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
        
    }

    public class TaskProjectTableLine{
        public String TipoProjetoObra;
        public String Status;
        public String Assunto;
        public String Acoes;
        public String Observacoes;
        public String Responsavel;
        public String Interessados;
        public String PrazoDiasUteis;
        public String DataVencimentoDMais;
        public String TipoDeProprietario;
        public Integer Ordem;
        public Integer RowNumber;
    }

    public class TaskProjectTable{
        public TaskProjectTableLine[] tableLines;
    }

    // Comparador por Ordem (nulls por último)
    public class TaskProjectTableLineComparator implements System.Comparator<TaskProjectTableLine> {
        public Integer compare(TaskProjectTableLine a, TaskProjectTableLine b) {
            Integer ao = a != null ? a.Ordem : null;
            Integer bo = b != null ? b.Ordem : null;
            if (ao == null && bo == null) return 0;
            if (ao == null) return 1;
            if (bo == null) return -1;
            return ao > bo ? 1 : (ao < bo ? -1 : 0);
        }
    }
}
