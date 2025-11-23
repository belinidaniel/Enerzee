/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-23-2025
 * @last modified by  : Daniel Belini
**/
public class ProjetoBO {

    public static Map<String, User> userEmailToUser = new Map<String, User>();
    
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

    public static void updateCartaAprovacaoFields(List<Projeto__c> projects){
        if(projects == null || projects.isEmpty()){
            return;
        }

        Date today = Date.today();
        for(Projeto__c project : projects){
            if(project == null){
                continue;
            }

            if(String.isBlank(project.CartaAprovacaoTipo__c) || project.CartaAprovacaoData__c == null){
                project.CartaAprovacaoDiasRestantes__c = null;
                continue;
            }

            Date expirationDate = calculateCartaAprovacaoExpiration(project.CartaAprovacaoData__c, project.CartaAprovacaoTipo__c);

            if(expirationDate == null){
                project.CartaAprovacaoDiasRestantes__c = null;
                continue;
            }

            Integer daysRemaining = today.daysBetween(expirationDate);
            project.CartaAprovacaoDiasRestantes__c = daysRemaining;

            if(daysRemaining < 0){
            } else if(daysRemaining <= 15){
            } else {
            }
        }
    }

    private static Date calculateCartaAprovacaoExpiration(Date baseDate, String tipo){
        if(baseDate == null || String.isBlank(tipo)){
            return null;
        }

        String normalizedType = tipo.trim();
        if(normalizedType == 'Informacao_de_Acesso'){
            return baseDate.addDays(60);
        } else if(normalizedType == 'Disponibilidade_de_Energia'){
            return baseDate.addDays(90);
        } else if(normalizedType == 'Microgeracao'){
            return baseDate.addDays(120);
        } else if(normalizedType == 'Minigeracao'){
            return baseDate.addYears(1);
        } else if(normalizedType == 'Posto_ou_Subestacao'){
            return baseDate.addYears(2);
        }

        return null;
    }
    
    public static void createTasks(List<Projeto__c> newRecordList, Map<Id, Projeto__c> oldMap){

        Map<String, Id> recordTypeStringCodeToId = new Map<String, Id>{
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

        Map<Id, String> recordTypeIdToStringCode = new Map<ID, String>{
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

        Map<String, String> statusCodeToStatus = new Map<String, String>{
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

        Map<String, String> statusToStatusCode = new Map<String, String>{
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

            //  Nome do tipo de registro do Projeto
            String recordTypeName = Schema.getGlobalDescribe().get('Projeto__c').getDescribe().getRecordTypeInfosById().get(project.RecordTypeId).getName();

            //  Map com os Templates das Tasks a serem criadas de acordo com o Status do Projeto atual
            Map<String, List<TaskProjectTableLine>> mapStatusToTasksTemplate = mapRecordTypesToStatusTasks.get(recordTypeIdToStringCode.get(ProjetoUtils.getRecordTypeIdByName(recordTypeName)));
			
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
                
                for(TaskProjectTableLine line : lines){
                    if(
                        (
                            line.Assunto.contains('DELEGAR PROJETISTA') ||
                            line.Assunto.contains('DELEGAR GESTOR DE OBRAS')
                        )
                     ){
                        System.debug('line '+ line);
                        interessadosList = line == null ? null : line.Interessados != null && line.Interessados != '' ? line.Interessados.split(';') : null;
                        System.debug('interessadosList '+ interessadosList);
                        if(line != null){
                            tasksToInsert.add(createTask(line, project, interessadosList, true));
                        }
                        if(interessadosList != null && recordTypesToValidateTwoResponsibles.contains(project.RecordTypeId)){
                            line = mapStatusToTasksTemplate.get(key)[1];
                            interessadosList = line.Interessados != null && line.Interessados != '' ? line.Interessados.split(';') : null;

                            tasksToInsert.add(createTask(line, project, interessadosList, true));
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

                    for(TaskProjectTableLine line : lines){
                        if(
                            (
                                !line.Assunto.contains('DELEGAR PROJETISTA') && 
                                !line.Assunto.contains('DELEGAR GESTOR DE OBRAS')
                            )
                        ){
                            if(shouldUFVPhaseBeCreated(project, line.Assunto, recordTypesUFV, financimentoProjectOpportunityIdsToSkipPhasesUFV)){
                                interessadosList = line.Interessados != null && line.Interessados != '' ? line.Interessados.split(';') : null;

                                tasksToInsert.add(createTask(line, project, interessadosList, false));
                            }
                        }
                    }
                }

                //  Se Status do Projeto estiver mudando, validar se a mudança de Status deve disparar
                //  a criação das Tasks parametrizadas para este Status

                if(ProjetoUtils.isStatusChanging(project, oldMap.get(project.Id)) && recordTypeToStatusChangesList != null && recordTypeIdToStringCode != null){

                    //  Itera sobre o Map que relaciona o tipo de registro com os Status que geram criação de Tasks,
                    //  baseando-se no tipo de registro do Projeto atual
                    for(String statusToCreateTaskOnChanging : recordTypeToStatusChangesList.get(recordTypeIdToStringCode.get(ProjetoUtils.getRecordTypeIdByName(recordTypeName)))){

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
                            for(TaskProjectTableLine line : lines){
                                if(shouldUFVPhaseBeCreated(project, line.Assunto, recordTypesUFV, financimentoProjectOpportunityIdsToSkipPhasesUFV)){
                                    interessadosList = line.Interessados != null && line.Interessados != '' ? line.Interessados.split(';') : null;

                                    tasksToInsert.add(createTask(line, project, interessadosList, false));
                                }
                            }
                            break;
                        }
                    }
                    continue;
                }
            }
        }
        // insert tasksToInsert;
    }

    public static Task createTask(TaskProjectTableLine line, Projeto__c projeto, List<String> interessadosList, Boolean isFirst){
        Map<String, User> userRoleToUser = new Map<String, User>{
            'PROJETISTA'                 => ProjetoUtils.getProjetistaById(projeto.Projetista__c),
            'GESTOR_DE_OBRAS'            => ProjetoUtils.getGestorObrasById(projeto.GestorObra__c)
        };
            
        Map<String, Group> groupRoleToGroup = ProjetoUtils.getQueueIdByName();
        sObject taskOwner;
        if(line.Responsavel =='PROJETISTA' ||line.Responsavel =='GESTOR_DE_OBRAS' ){
            taskOwner = userRoleToUser.get(line.Responsavel);
            if(taskOwner == null){
                string role = line.Responsavel == 'PROJETISTA' ? 'Projetista' : 'Gestor de Obras';
                projeto.addError('É necessário informar um ' + role + ' para o projeto!');
            }
        }else{
            taskOwner = groupRoleToGroup.get(line.Responsavel);
        }
     
        System.debug('line ' + line);

        System.debug('taskOwner ' + taskOwner);
        Task task = new Task(
            TipoObraProjeto__c     = Schema.getGlobalDescribe().get('Projeto__c').getDescribe().getRecordTypeInfosById().get(projeto.RecordTypeId).getName(),
            StatusProjeto__c       = projeto.Status__c,
            Subject                = line.Assunto,
            Description            = line.Acoes,
            WhatId                 = projeto.Id,
            PrazoDiasUteis__c      = line.PrazoDiasUteis,
            OwnerId                = userinfo.getUserId()
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

        Integer daysToConsiderActivity = 
            line.DataVencimentoDMais != null && line.DataVencimentoDMais != '' && line.DataVencimentoDMais != '\r' ? 
            Integer.valueOf(line.DataVencimentoDMais.replaceAll('\n', '').replaceAll('\t', '').replaceAll('\r', '')) : 10;

        task.ActivityDate = 
        task.Subject.equalsIgnoreCase('RECEBIMENTO DOS MATERIAIS COMPLEMENTARES') || 
        task.Subject.equalsIgnoreCase('RECEBIMENTO DO KIT WEG') ?
        TaskBO.getActivityDateBasedOnWorkingDays(Date.valueOf(projeto.CreatedDate), 60) :
        TaskBO.getActivityDateBasedOnWorkingDays(System.today(), daysToConsiderActivity);

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
        Map<Id, List<Task>> projectIdToTaskList = new Map<Id, List<Task>>();
        for(Task task : [
            SELECT  Id, Status, WhatId
            FROM    Task
            WHERE   WhatId IN :Collection.of(newRecordList).pluckNotNullStrings(Projeto__c.Id)
        ]){
            if(!projectIdToTaskList.containsKey(task.WhatId)){
                projectIdToTaskList.put(task.WhatId, new List<Task>());
            }
            projectIdToTaskList.get(task.WhatId).add(task);
        }

        for(Projeto__c project : newRecordList){
            if(ProjetoUtils.isStatusChanging(project, oldMap.get(project.Id))){
                if(project == null || projectIdToTaskList.get(project.Id) == null){
                    continue;
                }
                for(Task task : projectIdToTaskList.get(project.Id)){
                    if(!task.Status.equalsIgnoreCase(TaskUtils.STATUS_CONCLUIDO)){
                        // project.addError('Todas as tarefas existentes para esse projeto precisam estar concluídas antes de avançar de fase!');
                        // break;
                    }
                }
            }
        }
    }

    public static TaskProjectTable getTaskProjectTableFromStaticResource(){
        StaticResource taskProjectTable = [
            SELECT  Id, Body 
            FROM    StaticResource 
            WHERE   Name = 'TabelaTarefasProjetos'
            LIMIT   1
        ];
        String tableBody = taskProjectTable.Body.toString();

        CSVReader tableBodyCSVReader = new CSVReader(tableBody, ';');

        tableBodyCSVReader.readLine();

        String[] tableBodyLine = tableBodyCSVReader.readLine();

        TaskProjectTable table = new TaskProjectTable();
        table.tableLines = new List<TaskProjectTableLine>();

        while (tableBodyLine != null){
            TaskProjectTableLine line = new TaskProjectTableLine();

            line.TipoProjetoObra     = String.valueOf(tableBodyLine[0]);
            line.Status              = String.valueOf(tableBodyLine[1]);
            line.Assunto             = String.valueOf(tableBodyLine[2]);
            line.Acoes               = String.valueOf(tableBodyLine[3]);
            line.Observacoes         = String.valueOf(tableBodyLine[4]);
            line.Responsavel         = String.valueOf(tableBodyLine[5]);
            line.Interessados        = String.valueOf(tableBodyLine[6]);
            line.PrazoDiasUteis      = String.valueOf(tableBodyLine[7]);
            line.DataVencimentoDMais = String.valueOf(tableBodyLine[8]);
            line.TipoDeProprietario  = String.valueOf(tableBodyLine[9]);

            table.tableLines.add(line);

            tableBodyLine = tableBodyCSVReader.readLine();
        }
        
        if(tableBodyLine != null){
            TaskProjectTableLine line = new TaskProjectTableLine();

            line.TipoProjetoObra     = String.valueOf(tableBodyLine[0]);
            line.Status              = String.valueOf(tableBodyLine[1]);
            line.Assunto             = String.valueOf(tableBodyLine[2]);
            line.Acoes               = String.valueOf(tableBodyLine[3]);
            line.Observacoes         = String.valueOf(tableBodyLine[4]);
            line.Responsavel         = String.valueOf(tableBodyLine[5]);
            line.Interessados        = String.valueOf(tableBodyLine[6]);
            line.PrazoDiasUteis      = String.valueOf(tableBodyLine[7]);
            line.DataVencimentoDMais = String.valueOf(tableBodyLine[8]);
            line.TipoDeProprietario  = String.valueOf(tableBodyLine[9]);

            table.tableLines.add(line);
        }
        return table;
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
    }

    public class TaskProjectTable{
        public TaskProjectTableLine[] tableLines;
    }
}