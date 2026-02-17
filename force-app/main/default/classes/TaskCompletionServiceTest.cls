@isTest
private class TaskCompletionServiceTest {
    @testSetup
    static void setup() {
        Id contratosId = ensureQueue('Contratos', 'Contratos');
        ensureQueueSObject(contratosId, 'Task');

        Id viabilidadeId = ensureQueue('AnalistaViabilidade', 'Analistas de Viabilidade');
        ensureQueueSObject(viabilidadeId, 'Task');
    }

    @isTest
    static void createsFollowUpForDocumentacaoComercial() {
        Projeto__c project = (Projeto__c) TestFactory.createSObject(new Projeto__c(), true);
        project.DocumentacaoComercialPendencia__c = 'RG e CPF do responsável';
        project.DocumentacaoCriarAtividadeContratos__c = true;
        update project;

        Task task = new Task(
            Subject = TaskUtils.SUBJECT_VERIFICAR_DOCUMENTACAO_COMERCIAL,
            Status = 'Open',
            WhatId = project.Id,
            OwnerId = UserInfo.getUserId()
        );
        insert task;

        Test.startTest();
        TaskCompletionService.CompletionResult result = TaskCompletionService.completeWithComment(task.Id, 'Favor anexar documentos.', null, null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Result success');

        Task updatedTask = [SELECT Status FROM Task WHERE Id = :task.Id];
        System.assertEquals(TaskUtils.STATUS_CONCLUIDO, updatedTask.Status, 'Task should be closed');

        Task followUp = [
            SELECT OwnerId, Subject, Description
            FROM Task
            WHERE WhatId = :project.Id
                AND Subject = :('Follow-up: ' + TaskUtils.SUBJECT_VERIFICAR_DOCUMENTACAO_COMERCIAL)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Group ownerQueue = [SELECT DeveloperName FROM Group WHERE Id = :followUp.OwnerId];
        System.assertEquals('Contratos', ownerQueue.DeveloperName, 'Follow-up should go to Contratos queue');
        System.assert(followUp.Description.contains('Favor anexar documentos.'), 'Should include comment in description');
        System.assert(followUp.Description.contains('Documentação faltante: RG e CPF do responsável'), 'Should include missing docs');
    }

    @isTest
    static void createsFollowUpForViabilidadeTecnica() {
        Projeto__c project = (Projeto__c) TestFactory.createSObject(new Projeto__c(), true);
        project.ViabilidadeTecnicaPendencia__c = 'Laudo de carga e memorial descritivo';
        project.CriarAtividadeViabilidadeTecnica__c = true;
        update project;

        Task task = new Task(
            Subject = TaskUtils.SUBJECT_VERIFICAR_VIABILIDADE_TECNICA,
            Status = 'Open',
            WhatId = project.Id,
            OwnerId = UserInfo.getUserId()
        );
        insert task;

        Test.startTest();
        TaskCompletionService.CompletionResult result = TaskCompletionService.completeWithComment(task.Id, 'Pendências de viabilidade.', null, null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Result success');

        Task updatedTask = [SELECT Status FROM Task WHERE Id = :task.Id];
        System.assertEquals(TaskUtils.STATUS_CONCLUIDO, updatedTask.Status, 'Task should be closed');

        Task followUp = [
            SELECT OwnerId, Subject, Description
            FROM Task
            WHERE WhatId = :project.Id
                AND Subject = :('Follow-up: ' + TaskUtils.SUBJECT_VERIFICAR_VIABILIDADE_TECNICA)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Group ownerQueue = [SELECT DeveloperName FROM Group WHERE Id = :followUp.OwnerId];
        System.assertEquals('AnalistaViabilidade', ownerQueue.DeveloperName, 'Follow-up should go to viabilidade queue');
        System.assert(followUp.Description.contains('Pendências de viabilidade.'), 'Should include comment in description');
        System.assert(followUp.Description.contains('Pendências da viabilidade técnica: Laudo de carga e memorial descritivo'), 'Should include missing viability info');
    }

    private static Id ensureQueue(String developerName, String queueName) {
        List<Group> existing = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
                AND DeveloperName = :developerName
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Group queue = new Group(
            DeveloperName = developerName,
            Name = queueName,
            Type = 'Queue'
        );
        insert queue;
        return queue.Id;
    }

    private static void ensureQueueSObject(Id queueId, String sObjectType) {
        List<QueueSobject> existing = [
            SELECT Id
            FROM QueueSobject
            WHERE QueueId = :queueId
                AND SObjectType = :sObjectType
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new QueueSobject(
                QueueId = queueId,
                SObjectType = sObjectType
            );
        }
    }
}
