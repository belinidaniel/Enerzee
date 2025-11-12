import { LightningElement, api } from 'lwc';

export default class ShowPdfById extends LightningElement {
    @api fileId;
    @api heightInRem;

    get pdfHeight() {
        return this.heightInRem + 'rem';
    }

    get url() {
        return `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=068Ha000002i7kb&operationContext=CHATTER&contentId=05THa000004Bcfe&page=0`; // Correct URL for rendering the document
    }
}