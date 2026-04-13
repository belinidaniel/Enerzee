/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class GORecordsTOTest {
  @IsTest
  static void shouldSerializeToJson() {
    GORecordsTO record = new GORecordsTO();
    record.IdSalesForce = 'a001x00000ABC';
    record.Status = 1;
    record.SubStatus = 2;
    record.TechnicalVisitDate = '2026-02-01T12:00:00Z';
    record.FinancingProcessDetail = '{"selected":true}';
    record.OptionsFinanciamentos = new List<GORecordsTO.FinancingOptionTO>{
      new GORecordsTO.FinancingOptionTO(
        'Opção 1 - 12 Parcelas de R$ 123,45',
        'PS-000001',
        1,
        true
      )
    };
    record.Value = 123.45;

    String jsonBody = JSON.serialize(record);
    System.assert(jsonBody.contains('IdSalesForce'));
    System.assert(jsonBody.contains('TechnicalVisitDate'));
    System.assert(jsonBody.contains('FinancingProcessDetail'));
    System.assert(jsonBody.contains('OptionsFinanciamentos'));
    System.assert(jsonBody.contains('OptionId'));
    System.assert(jsonBody.contains('OptionType'));
    System.assert(jsonBody.contains('OptionSelected'));
  }
}
