/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Belini
 * @test              : MetaGraphApiServiceTest
 **/
/**
 * @description Agenda o refresh de métricas Meta Ads.
 */
public with sharing class MetaInsightsRefreshSchedulable implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new MetaInsightsRefreshBatch('lifetime'), 20);
  }
}
