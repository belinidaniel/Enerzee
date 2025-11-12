import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadFile from '@salesforce/apex/FileUploadController.uploadFile';
import deleteFile from '@salesforce/apex/FileUploadController.deleteFile';

export default class FileUploadSobject extends LightningElement {
	@api recordId;
	@api fileName;
	@track file;
	@track fileUploaded = false;
	@track fileId;
	@track isLoading = false;

	handleFileChange(event) {
		const file = event.target.files[0];
		if (file) {
			if (file.type !== 'application/pdf') {
				this.dispatchEvent(new ShowToastEvent({
					title: 'Erro',
					message: 'Por favor, selecione um arquivo PDF.',
					variant: 'error'
				}));
				return;
			}
			this.file = file;
			this.isLoading = true;
			this.uploadFile();
		}
	}

	uploadFile() {
		const reader = new FileReader();
		reader.onload = () => {
			const base64 = reader.result.split(',')[1];
			// Adiciona o tipo do arquivo para garantir PDF no backend
			uploadFile({
				recordId: this.recordId,
				fileName: this.fileName || this.file.name,
				base64Data: base64,
				contentType: 'application/pdf'
			})
			.then(result => {
				this.fileUploaded = true;
				this.fileId = result;
				this.isLoading = false;
				this.dispatchEvent(new ShowToastEvent({
					title: 'Success',
					message: 'Arquivo PDF enviado com sucesso',
					variant: 'success'
				}));
			})
			.catch(error => {
				this.isLoading = false;
				this.dispatchEvent(new ShowToastEvent({
					title: 'Error',
					message: error.body ? error.body.message : error.message,
					variant: 'error'
				}));
			});
		};
		reader.readAsDataURL(this.file);
	}

	handleRemoveFile() {
		deleteFile({ fileId: this.fileId })
			.then(() => {
				this.fileUploaded = false;
				this.file = null;
				this.fileId = null;
				this.isLoading = false;
				this.dispatchEvent(new ShowToastEvent({
					title: 'Removed',
					message: 'File removed successfully',
					variant: 'info'
				}));
			})
			.catch(error => {
				this.isLoading = false;
				this.dispatchEvent(new ShowToastEvent({
					title: 'Error',
					message: error.body ? error.body.message : error.message,
					variant: 'error'
				}));
			});
	}
}