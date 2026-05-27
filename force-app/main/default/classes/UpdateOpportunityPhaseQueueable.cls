/**
 * @description       : Processa em lotes as oportunidades que não foram sincronizadas com sucesso na Nivello,
 *                       do mais antigo para o mais recente. Cada execução pega até BATCH_SIZE registros e encadeia o próximo lote.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-27-2026
 * @last modified by  : Daniel Belini
 * @test              : UpdateOpportunityPhaseQueueableTest
 **/
public class UpdateOpportunityPhaseQueueable implements Queueable, Database.AllowsCallouts {
  private static final Integer BATCH_SIZE = 50;

  private final Date cutoffDate;

  public UpdateOpportunityPhaseQueueable(Date cutoffDate) {
    this.cutoffDate = cutoffDate;
  }

  public void execute(QueueableContext ctx) {
    List<Opportunity> batch = [
      SELECT Id
      FROM Opportunity
      WHERE
        LastModifiedDate >= :cutoffDate
        AND (SucessoIntegracaoNivello__c = FALSE
        OR SucessoIntegracaoNivello__c = NULL)
        AND IsDeleted = FALSE
      ORDER BY LastModifiedDate ASC
      LIMIT :BATCH_SIZE
    ];

    if (batch.isEmpty()) {
      System.debug(
        '[UpdateOpportunityPhaseQueueable] No pending opportunities. Done.'
      );
      return;
    }

    Set<Id> batchIds = new Map<Id, Opportunity>(batch).keySet();
    System.debug(
      '[UpdateOpportunityPhaseQueueable] Processing ' +
        batchIds.size() +
        ' opportunities...'
    );

    ProposalService.updateOpportunityPhase(batchIds);

    System.debug(
      '[UpdateOpportunityPhaseQueueable] Batch dispatched. Checking for more...'
    );

    Integer remaining = [
      SELECT COUNT()
      FROM Opportunity
      WHERE
        LastModifiedDate >= :cutoffDate
        AND (SucessoIntegracaoNivello__c = FALSE
        OR SucessoIntegracaoNivello__c = NULL)
        AND IsDeleted = FALSE
    ];

    if (remaining > 0) {
      System.debug(
        '[UpdateOpportunityPhaseQueueable] ' +
          remaining +
          ' remaining. Enqueueing next batch.'
      );
      System.enqueueJob(new UpdateOpportunityPhaseQueueable(cutoffDate));
    } else {
      System.debug(
        '[UpdateOpportunityPhaseQueueable] All opportunities processed.'
      );
    }
  }
}
