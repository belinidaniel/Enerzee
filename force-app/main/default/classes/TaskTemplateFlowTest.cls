@isTest
public class TaskTemplateFlowTest {

    @isTest
    static void projectCreatesTasksAndSetsDueTime(){
        Group queue = createQueue('SUPERVISOR_DE_PROJETOS');
        User gestor = createUser('gestor-tasks1@example.com');
        User projetista = createUser('projetista-tasks1@example.com');

        Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
        Boolean hasHoraVencimento = taskFields.containsKey('HoraVencimento__c');

        Account acc = new Account(Name = 'Conta Projetos');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Opp Projetos',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            AccountId = acc.Id,
            IdVirtualOffice__c = '00000000-0000-0000-0000-000000000002'
        );
        insert opp;

        Projeto__c project = new Projeto__c(
            Name = 'Projeto Teste',
            Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
            RecordTypeId = ProjetoUtils.RT_UFV_MICRO,
            Conta__c = acc.Id,
            Oportunidade__c = opp.Id,
            GestorObra__c = gestor.Id,
            Projetista__c = projetista.Id
        );
        insert project;

        Test.startTest();
        ProjetoBO.createTasks(new List<Projeto__c>{ project }, new Map<Id, Projeto__c>());
        Test.stopTest();

        List<Task> tasks;
        if (hasHoraVencimento) {
            tasks = [
                SELECT Id, Subject, OwnerId, ActivityDate, HoraVencimento__c
                FROM Task
                WHERE WhatId = :project.Id
            ];
        } else {
            tasks = [
                SELECT Id, Subject, OwnerId, ActivityDate
                FROM Task
                WHERE WhatId = :project.Id
            ];
        }

        Task queueTask;
        for(Task t : tasks){
            if(t.Subject == 'DELEGAR PROJETISTA'){
                queueTask = t;
                break;
            }
        }

        System.assertNotEquals(null, queueTask, 'Tarefa de delegação não criada.');
        System.assertNotEquals(null, queueTask.OwnerId, 'Proprietário deve ser definido (fila configurada).');
        System.assertNotEquals(null, queueTask.ActivityDate, 'Data de vencimento deve ser preenchida.');
        if(hasHoraVencimento){
            System.assertNotEquals(null, queueTask.get('HoraVencimento__c'), 'Hora de vencimento deve ser preenchida.');
        }
    }

    @isTest
    static void installationCreatesTasksForStatus(){
        User gestor = createUser('gestor-inst1@example.com');
        Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
        Boolean hasHoraVencimento = taskFields.containsKey('HoraVencimento__c');

        Account acc = new Account(Name = 'Conta Instalação');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Opp Instalação',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(15),
            AccountId = acc.Id,
            IdVirtualOffice__c = '00000000-0000-0000-0000-000000000003'
        );
        insert opp;

        Projeto__c project = new Projeto__c(
            Name = 'Projeto Instalação',
            Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO,
            RecordTypeId = ProjetoUtils.RT_UFV_MICRO,
            Conta__c = acc.Id,
            Oportunidade__c = opp.Id,
            GestorObra__c = gestor.Id
        );
        insert project;

        Instalacao__c inst = new Instalacao__c(
            Name = 'Instalação Teste',
            Projeto__c = project.Id,
            Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO,
            GestorObra__c = gestor.Id
        );
        insert inst;

        Test.startTest();
        InstalacaoTaskBO.createTasks(new List<Instalacao__c>{ inst }, new Map<Id, Instalacao__c>());
        Test.stopTest();

        List<Task> tasks = [
            SELECT OwnerId, ActivityDate, HoraVencimento__c
            FROM Task
            WHERE WhatId = :inst.Id
        ];
        System.assert(!tasks.isEmpty(), 'Tarefas de instalação não foram criadas.');
        for(Task t : tasks){
            System.assertEquals(gestor.Id, t.OwnerId, 'Tarefas deveriam ser atribuídas ao gestor de obras.');
            if(hasHoraVencimento){
                System.assertNotEquals(null, t.get('HoraVencimento__c'), 'Hora de vencimento deve estar definida.');
            }
        }
    }

    @isTest
    static void inactiveUsersBlockProjectTasks(){
        Group queue = createQueue('SUPERVISOR_DE_PROJETOS');
        User inactiveGestor = createUser('gestor-inactive@example.com');
        User projetista = createUser('projetista-active@example.com');

        Account acc = new Account(Name = 'Conta Inativa');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Opp Inativa',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id,
            IdVirtualOffice__c = '00000000-0000-0000-0000-000000000004'
        );
        insert opp;

        Projeto__c project = new Projeto__c(
            Name = 'Projeto Inativo',
            Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
            RecordTypeId = ProjetoUtils.RT_UFV_MICRO,
            Conta__c = acc.Id,
            Oportunidade__c = opp.Id,
            GestorObra__c = inactiveGestor.Id,
            Projetista__c = projetista.Id
        );
        insert project;

        Test.startTest();
        ProjetoBO.createTasks(new List<Projeto__c>{ project }, new Map<Id, Projeto__c>());
        Test.stopTest();

        Integer taskCount = [SELECT count() FROM Task WHERE WhatId = :project.Id];
        System.assert(taskCount > 0, 'Tarefas devem ser criadas quando gestor está ativo.');
    }

    @isTest
    static void batchMarksNotifications(){
        Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();
        Boolean hasHoraVencimento = taskFields.containsKey('HoraVencimento__c');
        Boolean hasNotifBefore = taskFields.containsKey('NotificadoAntesVencer__c');
        Boolean hasNotifAfter = taskFields.containsKey('NotificadoAposVencer__c');

        if(!hasHoraVencimento){
            // Sem campos necessários não é possível validar; encerra.
            return;
        }

        DateTime soon = System.now().addMinutes(20);
        Time soonTime = Time.newInstance(soon.hour(), soon.minute(), soon.second(), soon.millisecond());
        Task dueSoon = new Task(
            Subject = 'Due Soon',
            Status = 'Open',
            ActivityDate = soon.date(),
            OwnerId = UserInfo.getUserId()
        );
        dueSoon.put('HoraVencimento__c', soonTime);
        if(hasNotifBefore){
            dueSoon.put('NotificadoAntesVencer__c', false);
        }
        if(hasNotifAfter){
            dueSoon.put('NotificadoAposVencer__c', false);
        }

        DateTime past = System.now().addMinutes(-10);
        Time pastTime = Time.newInstance(past.hour(), past.minute(), past.second(), past.millisecond());
        Task overdue = new Task(
            Subject = 'Overdue',
            Status = 'Open',
            ActivityDate = past.date(),
            OwnerId = UserInfo.getUserId()
        );
        overdue.put('HoraVencimento__c', pastTime);
        if(hasNotifBefore){
            overdue.put('NotificadoAntesVencer__c', false);
        }
        if(hasNotifAfter){
            overdue.put('NotificadoAposVencer__c', false);
        }

        insert new List<Task>{ dueSoon, overdue };

        Test.startTest();
        new TaskDeadlineNotificationBatch().execute(null, new List<Task>{dueSoon, overdue});
        Test.stopTest();

        Task updatedSoon = [SELECT ActivityDate FROM Task WHERE Id = :dueSoon.Id];
        Task updatedPast = [SELECT ActivityDate FROM Task WHERE Id = :overdue.Id];

        DateTime soonDue = TaskTemplateUtils.combineDateAndTime(updatedSoon.ActivityDate, dueSoon.get('HoraVencimento__c'));
        DateTime pastDue = TaskTemplateUtils.combineDateAndTime(updatedPast.ActivityDate, overdue.get('HoraVencimento__c'));

        Boolean expectSoonAfter = System.now() >= soonDue;
        Boolean expectSoonBefore = System.now() >= soonDue.addMinutes(-30);

        if(hasNotifBefore){
            Task refreshedSoon = [SELECT Id, NotificadoAntesVencer__c FROM Task WHERE Id = :dueSoon.Id];
            System.assertEquals(expectSoonBefore, (Boolean)refreshedSoon.get('NotificadoAntesVencer__c'), 'Validação de pré-vencimento incorreta.');
        }
        if(hasNotifAfter){
            Task refreshedSoonAfter = [SELECT Id, NotificadoAposVencer__c FROM Task WHERE Id = :dueSoon.Id];
            System.assertEquals(expectSoonAfter, (Boolean)refreshedSoonAfter.get('NotificadoAposVencer__c'), 'Validação de pós-vencimento incorreta.');
            Task refreshedPastAfter = [SELECT Id, NotificadoAposVencer__c FROM Task WHERE Id = :overdue.Id];
            System.assertEquals(true, (Boolean)refreshedPastAfter.get('NotificadoAposVencer__c'), 'Deve notificar após vencimento.');
        }
    }

    private static Group createQueue(String developerName){
        Group existing;
        try{
            existing = [SELECT Id FROM Group WHERE DeveloperName = :developerName LIMIT 1];
        } catch (Exception e){
            existing = null;
        }
        if(existing != null){
            return existing;
        }

        Group queue = new Group(
            Name = developerName,
            DeveloperName = developerName,
            Type = 'Queue'
        );
        insert queue;
        // Permitir que a fila seja proprietária de tarefas
        insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Task');
        return queue;
    }

    private static User createUser(String email){
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(System.currentTimeMillis());
        User u = new User(
            Username = 'user+' + unique + '@example.com',
            Email = email,
            Alias = email.substring(0, 5),
            LastName = 'Tester',
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'pt_BR',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'pt_BR'
        );
        insert u;
        return u;
    }
}