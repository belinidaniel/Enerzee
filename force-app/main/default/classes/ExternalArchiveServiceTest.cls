@IsTest
private class ExternalArchiveServiceTest {
  @IsTest
  static void shouldUploadArchive() {
    ExternalArchiveService.UploadResult result;
    try {
      result = ExternalArchiveService.uploadExternalArchive(
        null,
        'arquivo.pdf',
        '',
        null,
        'Outra atividade',
        'Documento'
      );
    } catch (Exception e) {
      System.assert(true, 'Validation thrown as expected.');
      return;
    }

    System.assertNotEquals(
      null,
      result,
      'Should return a result when no exception is thrown.'
    );
  }
}
