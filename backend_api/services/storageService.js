const fs = require('fs');
const path = require('path');
const db = require('../config/db');
const { google } = require('googleapis');
const { Dropbox } = require('dropbox');
const { Client } = require('@microsoft/microsoft-graph-client');
require('isomorphic-fetch');

// ✅ ĐẢM BẢO THƯ MỤC UPLOADS TỒN TẠI
const uploadDir = process.env.UPLOAD_DIR || './uploads';
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
    console.log(`✅ Created upload directory: ${uploadDir}`);
}

// ✅ LOCAL STORAGE STRATEGY
class LocalStorageStrategy {
    async upload(file) {
        // file là object được Multer sinh ra
        const timestamp = Date.now();
        const fileName = `${timestamp}-${file.originalname}`;
        const filePath = path.join(uploadDir, fileName);
        
        // Ghi file vào ổ cứng server
        fs.writeFileSync(filePath, file.buffer);
        
        console.log(`✅ File saved: ${filePath}`);
        
        return {
            url: filePath, // Đường dẫn thực tế trên server
            provider: 'local',
            size_bytes: file.size
        };
    }

    async delete(fileUrl) {
        try {
            if (fs.existsSync(fileUrl)) {
                fs.unlinkSync(fileUrl);
                console.log(`✅ File deleted: ${fileUrl}`);
            } else {
                console.log(`⚠️ File not found: ${fileUrl}`);
            }
        } catch (error) {
            console.error(`❌ Delete file error: ${error.message}`);
            throw error;
        }
    }
}

// ✅ GOOGLE DRIVE STORAGE STRATEGY
class GoogleDriveStrategy {
    constructor(userTokens) {
        /**
         * userTokens = {
         *   access_token: 'ya29.xxx',
         *   refresh_token: 'xxx',
         *   email: 'user@gmail.com'
         * }
         */
        this.userTokens = userTokens;
        this.oauth2Client = new google.auth.OAuth2(
            process.env.GOOGLE_CLIENT_ID,
            process.env.GOOGLE_CLIENT_SECRET,
            process.env.GOOGLE_REDIRECT_URI
        );
        
        // Set credentials
        this.oauth2Client.setCredentials({
            access_token: userTokens.access_token,
            refresh_token: userTokens.refresh_token
        });
        
        this.drive = google.drive({ version: 'v3', auth: this.oauth2Client });
    }

    async upload(file) {
        try {
            console.log(`📤 [GoogleDrive] Uploading: ${file.originalname}`);
            
            // Tạo folder "Refmind" nếu chưa có
            const folderId = await this._ensureRefmindFolder();
            
            // Upload file lên Google Drive
            const fileMetadata = {
                name: file.originalname,
                parents: [folderId] // Lưu trong folder Refmind
            };
            
            const media = {
                mimeType: file.mimetype,
                body: require('stream').Readable.from(file.buffer)
            };
            
            const response = await this.drive.files.create({
                requestBody: fileMetadata,
                media: media,
                fields: 'id, name, size, webViewLink'
            });
            
            console.log(`✅ [GoogleDrive] Uploaded: ${response.data.id}`);
            
            return {
                url: `gdrive://${response.data.id}`, // Custom scheme để phân biệt
                provider: 'gdrive',
                size_bytes: parseInt(response.data.size || file.size),
                webViewLink: response.data.webViewLink // Link xem trên browser
            };
            
        } catch (error) {
            console.error(`❌ [GoogleDrive] Upload error: ${error.message}`);
            
            // Nếu token hết hạn, thử refresh
            if (error.message.includes('invalid_grant') || error.message.includes('Token')) {
                throw new Error('Google Drive token expired. Please re-authenticate.');
            }
            
            throw error;
        }
    }

    async delete(fileUrl) {
        try {
            // fileUrl format: "gdrive://1A2B3C4D5E6F" 
            const fileId = fileUrl.replace('gdrive://', '');
            
            console.log(`🗑️ [GoogleDrive] Deleting: ${fileId}`);
            
            await this.drive.files.delete({
                fileId: fileId
            });
            
            console.log(`✅ [GoogleDrive] Deleted: ${fileId}`);
            
        } catch (error) {
            console.error(`❌ [GoogleDrive] Delete error: ${error.message}`);
            throw error;
        }
    }

    async download(fileUrl) {
        try {
            const fileId = fileUrl.replace('gdrive://', '');
            
            const response = await this.drive.files.get({
                fileId: fileId,
                alt: 'media'
            }, { responseType: 'stream' });
            
            return response.data; // Stream
            
        } catch (error) {
            console.error(`❌ [GoogleDrive] Download error: ${error.message}`);
            throw error;
        }
    }

    // Private: Đảm bảo có folder "Refmind" trên Google Drive
    async _ensureRefmindFolder() {
        try {
            // Tìm folder "Refmind"
            const response = await this.drive.files.list({
                q: "name='Refmind' and mimeType='application/vnd.google-apps.folder' and trashed=false",
                fields: 'files(id, name)',
                spaces: 'drive'
            });
            
            if (response.data.files.length > 0) {
                // Folder đã tồn tại
                return response.data.files[0].id;
            }
            
            // Tạo folder mới
            const folderMetadata = {
                name: 'Refmind',
                mimeType: 'application/vnd.google-apps.folder'
            };
            
            const folder = await this.drive.files.create({
                requestBody: folderMetadata,
                fields: 'id'
            });
            
            console.log(`✅ [GoogleDrive] Created Refmind folder: ${folder.data.id}`);
            return folder.data.id;
            
        } catch (error) {
            console.error(`❌ [GoogleDrive] Folder creation error: ${error.message}`);
            throw error;
        }
    }
}

// ✅ DROPBOX STORAGE STRATEGY
class DropboxStrategy {
    constructor(userTokens) {
        /**
         * userTokens = {
         *   access_token: 'xxx',
         *   refresh_token: 'xxx',
         *   email: 'user@email.com'
         * }
         */
        this.userTokens = userTokens;
        this.dbx = new Dropbox({ 
            accessToken: userTokens.access_token,
            clientId: process.env.DROPBOX_CLIENT_ID,
            clientSecret: process.env.DROPBOX_CLIENT_SECRET
        });
    }

    // 🔄 Refresh Access Token khi hết hạn
    async _refreshAccessToken() {
        try {
            console.log('🔄 [Dropbox] Refreshing access token...');
            
            const response = await fetch('https://api.dropboxapi.com/oauth2/token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                body: new URLSearchParams({
                    grant_type: 'refresh_token',
                    refresh_token: this.userTokens.refresh_token,
                    client_id: process.env.DROPBOX_CLIENT_ID,
                    client_secret: process.env.DROPBOX_CLIENT_SECRET
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Token refresh failed: ${JSON.stringify(errorData)}`);
            }

            const data = await response.json();
            const newAccessToken = data.access_token;

            // Update tokens
            this.userTokens.access_token = newAccessToken;

            // Recreate Dropbox client with new token
            this.dbx = new Dropbox({ 
                accessToken: newAccessToken,
                clientId: process.env.DROPBOX_CLIENT_ID,
                clientSecret: process.env.DROPBOX_CLIENT_SECRET
            });

            // Update database
            await db.query(`
                UPDATE user_cloud_connections
                SET access_token = $1
                WHERE email = $2 AND provider = 'dropbox'
            `, [newAccessToken, this.userTokens.email]);

            console.log('✅ [Dropbox] Token refreshed successfully');
            return true;
        } catch (error) {
            console.error('❌ [Dropbox] Token refresh failed:', error);
            throw new Error('Dropbox token refresh failed. Please re-authenticate.');
        }
    }

    async upload(file, retrying = false) {
        try {
            console.log(`📤 [Dropbox] Uploading: ${file.originalname}`);
            
            // Đảm bảo có folder /Refmind
            await this._ensureRefmindFolder();
            
            // Upload file vào folder /Refmind
            const timestamp = Date.now();
            const fileName = `${timestamp}-${file.originalname}`;
            const dropboxPath = `/Refmind/${fileName}`;
            
            const response = await this.dbx.filesUpload({
                path: dropboxPath,
                contents: file.buffer,
                mode: 'add',
                autorename: true,
                mute: false
            });
            
            console.log(`✅ [Dropbox] Uploaded: ${response.result.id}`);
            
            return {
                url: `dropbox://${response.result.id}`, // Custom scheme
                provider: 'dropbox',
                size_bytes: file.size,
                dropboxPath: response.result.path_display
            };
            
        } catch (error) {
            console.error(`❌ [Dropbox] Upload error:`, error);
            
            // Check token expiration - Try refresh once
            if (error.status === 401 && !retrying) {
                console.log('🔄 [Dropbox] Token expired, attempting refresh...');
                await this._refreshAccessToken();
                // Retry upload with new token
                return await this.upload(file, true);
            }
            
            if (error.status === 401 && retrying) {
                throw new Error('Dropbox token expired. Please re-authenticate.');
            }
            
            throw error;
        }
    }

    async delete(fileUrl, retrying = false) {
        try {
            // fileUrl format: "dropbox://id:xxxxx" hoặc path
            // Dropbox cần path để delete, không phải ID
            // Nên ta cần query metadata trước hoặc lưu path trong DB
            
            // Workaround: Lấy path từ metadata
            const fileId = fileUrl.replace('dropbox://', '');
            
            console.log(`🗑️ [Dropbox] Deleting file ID: ${fileId}`);
            
            // Get file metadata để lấy path
            const metadata = await this.dbx.filesGetMetadata({ path: fileId });
            
            // Delete file
            await this.dbx.filesDeleteV2({
                path: metadata.result.path_display
            });
            
            console.log(`✅ [Dropbox] Deleted: ${fileId}`);
            
        } catch (error) {
            console.error(`❌ [Dropbox] Delete error:`, error);
            
            // Check token expiration - Try refresh once
            if (error.status === 401 && !retrying) {
                console.log('🔄 [Dropbox] Token expired, attempting refresh...');
                await this._refreshAccessToken();
                return await this.delete(fileUrl, true);
            }
            
            throw error;
        }
    }

    async download(fileUrl, retrying = false) {
        try {
            const fileId = fileUrl.replace('dropbox://', '');
            
            console.log(`📥 [Dropbox] Downloading: ${fileId}`);
            
            const response = await this.dbx.filesDownload({ path: fileId });
            
            // Dropbox trả về file content trong response.result.fileBinary
            return Buffer.from(response.result.fileBinary);
            
        } catch (error) {
            console.error(`❌ [Dropbox] Download error:`, error);
            
            // Check token expiration - Try refresh once
            if (error.status === 401 && !retrying) {
                console.log('🔄 [Dropbox] Token expired, attempting refresh...');
                await this._refreshAccessToken();
                return await this.download(fileUrl, true);
            }
            
            throw error;
        }
    }

    // Private: Đảm bảo có folder "/Refmind" trên Dropbox
    async _ensureRefmindFolder(retrying = false) {
        try {
            // Check nếu folder đã tồn tại
            try {
                await this.dbx.filesGetMetadata({ path: '/Refmind' });
                // Folder exists
                return;
            } catch (error) {
                // Folder không tồn tại, tạo mới
                if (error.status === 409) {
                    // Folder already exists
                    return;
                }
                
                // Check token expiration
                if (error.status === 401 && !retrying) {
                    console.log('🔄 [Dropbox] Token expired in folder check, attempting refresh...');
                    await this._refreshAccessToken();
                    return await this._ensureRefmindFolder(true);
                }
                
                // If not 409, throw to outer catch
                if (error.status !== 409) {
                    throw error;
                }
            }
            
            // Tạo folder mới
            await this.dbx.filesCreateFolderV2({
                path: '/Refmind',
                autorename: false
            });
            
            console.log(`✅ [Dropbox] Created Refmind folder`);
            
        } catch (error) {
            // Nếu folder đã tồn tại, ignore error
            if (error.error && error.error.error_summary && error.error.error_summary.includes('conflict')) {
                console.log(`ℹ️ [Dropbox] Refmind folder already exists`);
                return;
            }
            
            // Check token expiration at folder creation
            if (error.status === 401 && !retrying) {
                console.log('🔄 [Dropbox] Token expired in folder creation, attempting refresh...');
                await this._refreshAccessToken();
                return await this._ensureRefmindFolder(true);
            }
            
            console.error(`❌ [Dropbox] Folder creation error:`, error);
            throw error;
        }
    }
}

// ✅ ONEDRIVE STORAGE STRATEGY
class OneDriveStrategy {
    constructor(userTokens) {
        /**
         * userTokens = {
         *   access_token: 'xxx',
         *   refresh_token: 'xxx',
         *   email: 'user@email.com'
         * }
         */
        this.userTokens = userTokens;
        this.client = Client.init({
            authProvider: (done) => {
                done(null, userTokens.access_token);
            }
        });
    }

    // 🔄 Refresh Access Token khi hết hạn
    async _refreshAccessToken() {
        try {
            console.log('🔄 [OneDrive] Refreshing access token...');
            
            const response = await fetch('https://login.microsoftonline.com/common/oauth2/v2.0/token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                body: new URLSearchParams({
                    client_id: process.env.ONEDRIVE_CLIENT_ID,
                    client_secret: process.env.ONEDRIVE_CLIENT_SECRET,
                    refresh_token: this.userTokens.refresh_token,
                    grant_type: 'refresh_token'
                })
            });

            if (!response.ok) {
                throw new Error(`Token refresh failed: ${response.statusText}`);
            }

            const data = await response.json();
            const newAccessToken = data.access_token;
            const newRefreshToken = data.refresh_token || this.userTokens.refresh_token;

            // Update tokens
            this.userTokens.access_token = newAccessToken;
            this.userTokens.refresh_token = newRefreshToken;

            // Recreate client with new token
            this.client = Client.init({
                authProvider: (done) => {
                    done(null, newAccessToken);
                }
            });

            // Update database (use existing db import at top of file)
            await db.query(`
                UPDATE user_cloud_connections
                SET access_token = $1, refresh_token = $2
                WHERE email = $3 AND provider = 'onedrive'
            `, [newAccessToken, newRefreshToken, this.userTokens.email]);

            console.log('✅ [OneDrive] Token refreshed successfully');
            return true;
        } catch (error) {
            console.error('❌ [OneDrive] Token refresh failed:', error);
            throw new Error('OneDrive token refresh failed. Please re-authenticate.');
        }
    }

    async upload(file, retrying = false) {
        try {
            console.log(`📤 [OneDrive] Uploading: ${file.originalname}`);
            
            // Đảm bảo có folder /Refmind
            await this._ensureRefmindFolder();
            
            // Upload file vào folder /Refmind
            const timestamp = Date.now();
            const fileName = `${timestamp}-${file.originalname}`;
            const oneDrivePath = `/Refmind/${fileName}`;
            
            // Upload file using Microsoft Graph API
            const uploadedFile = await this.client
                .api(`/me/drive/root:${oneDrivePath}:/content`)
                .put(file.buffer);
            
            console.log(`✅ [OneDrive] Uploaded: ${uploadedFile.id}`);
            
            return {
                url: `onedrive://${uploadedFile.id}`, // Custom scheme
                provider: 'onedrive',
                size_bytes: uploadedFile.size || file.size,
                webUrl: uploadedFile.webUrl
            };
            
        } catch (error) {
            console.error(`❌ [OneDrive] Upload error:`, error);
            
            // Check token expiration - Try refresh once
            if (error.statusCode === 401 && !retrying) {
                console.log('🔄 [OneDrive] Token expired, attempting refresh...');
                await this._refreshAccessToken();
                // Retry upload with new token
                return await this.upload(file, true);
            }
            
            if (error.statusCode === 401 && retrying) {
                throw new Error('OneDrive token expired. Please re-authenticate.');
            }
            
            throw error;
        }
    }

    async delete(fileUrl) {
        try {
            // fileUrl format: "onedrive://FILE_ID"
            const fileId = fileUrl.replace('onedrive://', '');
            
            console.log(`🗑️ [OneDrive] Deleting: ${fileId}`);
            
            await this.client
                .api(`/me/drive/items/${fileId}`)
                .delete();
            
            console.log(`✅ [OneDrive] Deleted: ${fileId}`);
            
        } catch (error) {
            console.error(`❌ [OneDrive] Delete error:`, error);
            throw error;
        }
    }

    async download(fileUrl) {
        try {
            const fileId = fileUrl.replace('onedrive://', '');
            
            console.log(`📥 [OneDrive] Downloading: ${fileId}`);
            
            // Get download URL
            const file = await this.client
                .api(`/me/drive/items/${fileId}`)
                .get();
            
            if (!file['@microsoft.graph.downloadUrl']) {
                throw new Error('Cannot get download URL');
            }
            
            // Download file content
            const response = await fetch(file['@microsoft.graph.downloadUrl']);
            const buffer = await response.buffer();
            
            return buffer;
            
        } catch (error) {
            console.error(`❌ [OneDrive] Download error:`, error);
            throw error;
        }
    }

    // Private: Đảm bảo có folder "/Refmind" trên OneDrive
    async _ensureRefmindFolder() {
        try {
            // Check if folder exists
            try {
                await this.client
                    .api('/me/drive/root:/Refmind')
                    .get();
                // Folder exists
                return;
            } catch (error) {
                // Folder doesn't exist, create it
                if (error.statusCode === 404) {
                    await this.client
                        .api('/me/drive/root/children')
                        .post({
                            name: 'Refmind',
                            folder: {},
                            '@microsoft.graph.conflictBehavior': 'fail'
                        });
                    
                    console.log(`✅ [OneDrive] Created Refmind folder`);
                } else {
                    throw error;
                }
            }
            
        } catch (error) {
            // If folder already exists, ignore
            if (error.statusCode === 409) {
                console.log(`ℹ️ [OneDrive] Refmind folder already exists`);
                return;
            }
            
            console.error(`❌ [OneDrive] Folder creation error:`, error);
            throw error;
        }
    }
}

// ✅ STORAGE SERVICE CLASS
class StorageService {
    constructor() {
        // Mặc định dùng Local Storage
        this.strategy = new LocalStorageStrategy();
    }

    setStrategy(strategy) {
        this.strategy = strategy;
    }

    async uploadFile(file) {
        return await this.strategy.upload(file);
    }

    async deleteFile(fileUrl) {
        return await this.strategy.delete(fileUrl);
    }

    // ✅ DATABASE METHODS
    async createStorageItem(userId, itemData) {
        let parentId = itemData.parent_id;
        if (parentId === "null" || parentId === "" || parentId === undefined) {
            parentId = null;
        }
        
        const query = `
            INSERT INTO storage_items 
            (user_id, parent_id, name, type, file_url, size_bytes, provider, has_pdf, metadata, is_favorite)
            VALUES ($1::TEXT, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10)
            RETURNING *;
        `;
        const values = [
            userId,
            parentId,
            itemData.name,
            itemData.type,
            itemData.file_url || null,
            itemData.size_bytes || 0,
            itemData.provider || 'local',
            itemData.has_pdf !== undefined ? itemData.has_pdf : true,
            JSON.stringify(itemData.metadata || {}),
            itemData.is_favorite || false
        ];
        const result = await db.query(query, values);
        return result.rows[0];
    }

    async getStorageItems(userId, parentId = null) {
        const query = `
            SELECT * FROM storage_items 
            WHERE user_id = $1::TEXT AND parent_id ${parentId ? '= $2' : 'IS NULL'}
            ORDER BY type DESC, name ASC;
        `;
        const values = parentId ? [userId, parentId] : [userId];
        const result = await db.query(query, values);
        return result.rows;
    }

    async deleteStorageItem(itemId, userId) {
        const query = `
            DELETE FROM storage_items 
            WHERE id = $1 AND user_id = $2::TEXT
            RETURNING *;
        `;
        const result = await db.query(query, [itemId, userId]);
        return result.rows[0];
    }
}

// ✅ EXPORT INSTANCE
// ✅ EXPORT INSTANCE & CLASSES
module.exports = new StorageService();
module.exports.StorageService = StorageService;
module.exports.LocalStorageStrategy = LocalStorageStrategy;
module.exports.GoogleDriveStrategy = GoogleDriveStrategy;
module.exports.DropboxStrategy = DropboxStrategy;
module.exports.OneDriveStrategy = OneDriveStrategy;