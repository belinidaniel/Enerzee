@IsTest
private class ApprovalProcessServiceTest {

    private static final Id OPPORTUNITY_ID = '006000000000001';
    private static final Id WORKITEM_ID = '04i000000000001';
    private static final Id PROCESS_INSTANCE_ID = '04g000000000001';

    private class MockApprovalGateway implements ApprovalProcessService.ApprovalGateway {
        Integer queryCalls = 0;
        Integer processCalls = 0;
        Set<Id> queriedTargetObjectIds = new Set<Id>();
        List<ProcessInstanceWorkitem> workitemsToReturn = new List<ProcessInstanceWorkitem>();
        List<Id> processedWorkitemIds = new List<Id>();
        List<String> processedActions = new List<String>();
        List<String> processedComments = new List<String>();

        public List<ProcessInstanceWorkitem> findPendingWorkitems(Set<Id> targetObjectIds) {
            queryCalls++;
            queriedTargetObjectIds = new Set<Id>(targetObjectIds);
            return workitemsToReturn;
        }

        public Approval.ProcessResult recall(Approval.ProcessWorkitemRequest request) {
            processCalls++;
            processedWorkitemIds.add(request.getWorkitemId());
            processedActions.add(request.getAction());
            processedComments.add(request.getComments());
            return null;
        }
    }

    @IsTest
    static void noRecallWhenStatusDoesNotChangeFromPendingToBlank() {
        MockApprovalGateway mockGateway = new MockApprovalGateway();
        ApprovalProcessService.setGateway(mockGateway);

        try {
            Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
                OPPORTUNITY_ID => new Opportunity(
                    Id = OPPORTUNITY_ID,
                    StatusAprovacaoDesconto__c = 'Pendente'
                )
            };
            Map<Id, Opportunity> newMap = new Map<Id, Opportunity>{
                OPPORTUNITY_ID => new Opportunity(
                    Id = OPPORTUNITY_ID,
                    StatusAprovacaoDesconto__c = 'Aprovado'
                )
            };

            Test.startTest();
            ApprovalProcessService.recallPendingDiscountApprovals(newMap, oldMap);
            Test.stopTest();

            System.assertEquals(0, mockGateway.queryCalls, 'Nao deve consultar workitems se nao houve transicao pendente->blank.');
            System.assertEquals(0, mockGateway.processCalls, 'Nao deve tentar recall se nao houve transicao pendente->blank.');
        } finally {
            ApprovalProcessService.resetGateway();
        }
    }

    @IsTest
    static void recallWhenStatusChangesFromPendingToBlank() {
        MockApprovalGateway mockGateway = new MockApprovalGateway();
        mockGateway.workitemsToReturn.add(new ProcessInstanceWorkitem(
            Id = WORKITEM_ID,
            ProcessInstanceId = PROCESS_INSTANCE_ID
        ));
        ApprovalProcessService.setGateway(mockGateway);

        try {
            Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
                OPPORTUNITY_ID => new Opportunity(
                    Id = OPPORTUNITY_ID,
                    StatusAprovacaoDesconto__c = 'Pendente'
                )
            };
            Map<Id, Opportunity> newMap = new Map<Id, Opportunity>{
                OPPORTUNITY_ID => new Opportunity(
                    Id = OPPORTUNITY_ID,
                    StatusAprovacaoDesconto__c = null
                )
            };

            Test.startTest();
            ApprovalProcessService.recallPendingDiscountApprovals(newMap, oldMap);
            Test.stopTest();

            System.assertEquals(1, mockGateway.queryCalls, 'Deve consultar workitems pendentes quando houver transicao pendente->blank.');
            System.assertEquals(true, mockGateway.queriedTargetObjectIds.contains(OPPORTUNITY_ID), 'A Opportunity alterada deve ser enviada para consulta.');
            System.assertEquals(1, mockGateway.processCalls, 'Deve tentar processar recall do approval pendente.');
            System.assertEquals(WORKITEM_ID, mockGateway.processedWorkitemIds[0], 'Deve processar o workitem retornado.');
            System.assertEquals('Removed', mockGateway.processedActions[0], 'A action do recall deve ser Removed.');
            System.assert(
                mockGateway.processedComments[0].contains('readequacao'),
                'O comentario deve explicar que o recall ocorreu por readequacao.'
            );
        } finally {
            ApprovalProcessService.resetGateway();
        }
    }
}