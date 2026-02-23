@IsTest
private class HelpDeskFilePayloadTest {
    @IsTest
    static void shouldCreatePayload() {
        HelpDeskFilePayload payload = new HelpDeskFilePayload();
        payload.fileName = 'arquivo.txt';
        payload.contentType = 'text/plain';
        payload.base64Data = EncodingUtil.base64Encode(Blob.valueOf('teste'));
        payload.humanSize = '5 KB';
        payload.name = 'Arquivo';

        System.assertEquals('arquivo.txt', payload.fileName);
        System.assertNotEquals(null, payload.base64Data);
    }
}