@IsTest
private class GORecordsTOTest {
    @IsTest
    static void shouldSerializeToJson() {
        GORecordsTO record = new GORecordsTO();
        record.IdSalesForce = 'a001x00000ABC';
        record.Status = 1;
        record.SubStatus = 2;
        record.TechnicalVisitDate = '2026-02-01T12:00:00Z';
        record.Value = 123.45;

        String jsonBody = JSON.serialize(record);
        System.assert(jsonBody.contains('IdSalesForce'));
        System.assert(jsonBody.contains('TechnicalVisitDate'));
    }
}
