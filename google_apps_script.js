/**
 * GOOGLE APPS SCRIPT: LICENSE & AUTO-UPDATE MANAGER
 * Super Skripsi Gandi - Backend System
 */

const SECRET_TOKEN = "SUPER_GANDI_SECURE_2024"; // GANTI DENGAN TOKEN RAHASIA ANDA

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    
    // 1. Validasi Secret Token
    if (data.token !== SECRET_TOKEN) {
      return createResponse({ status: "error", message: "Unauthorized" }, 401);
    }

    const action = data.action; // "activate" atau "check_status" atau "check_update"
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    if (action === "activate") {
      return handleActivation(ss, data);
    } else if (action === "check_update") {
      return handleCheckUpdate(ss, data);
    } else if (action === "validate") {
      return handleValidation(ss, data);
    } else if (action === "submit_survey") {
      return handleSurvey(ss, data);
    } else {
      return createResponse({ status: "error", message: "Invalid action" }, 400);
    }
    
  } catch (err) {
    return createResponse({ status: "error", message: err.toString() }, 500);
  }
}

// FUNGSI AKTIVASI LISENSI (1 KEY, 2 DEVICES)
function handleActivation(ss, data) {
  const sheet = ss.getSheetByName("Licenses");
  const rows = sheet.getDataRange().getValues();
  const key = data.license_key;
  const deviceId = data.device_id;
  const deviceName = data.device_name || "Unknown Device";
  
  for (let i = 1; i < rows.length; i++) {
    if (rows[i][0] === key) { // Kolom A: license_key
      if (rows[i][5] === "Blocked") {
        return createResponse({ status: "error", message: "Lisensi ini telah diblokir." });
      }

      const device1 = rows[i][1]; // Kolom B
      const device2 = rows[i][3]; // Kolom D
      
      // Jika sudah terdaftar di perangkat ini
      if (device1 === deviceId || device2 === deviceId) {
        return createResponse({ status: "success", message: "Perangkat sudah terdaftar." });
      }
      
      // Jika Slot 1 Kosong
      if (!device1) {
        sheet.getRange(i + 1, 2).setValue(deviceId);
        sheet.getRange(i + 1, 3).setValue(deviceName);
        sheet.getRange(i + 1, 7).setValue(new Date()); // Last Validated
        return createResponse({ status: "success", message: "Aktivasi berhasil (Slot 1)." });
      }
      
      // Jika Slot 2 Kosong
      if (!device2) {
        sheet.getRange(i + 1, 4).setValue(deviceId);
        sheet.getRange(i + 1, 5).setValue(deviceName);
        sheet.getRange(i + 1, 7).setValue(new Date()); // Last Validated
        return createResponse({ status: "success", message: "Aktivasi berhasil (Slot 2)." });
      }
      
      return createResponse({ status: "error", message: "Batas maksimal perangkat (2) telah tercapai." });
    }
  }
  
  return createResponse({ status: "error", message: "Kunci lisensi tidak ditemukan." });
}

// FUNGSI CEK AUTO-UPDATE
function handleCheckUpdate(ss, data) {
  const sheet = ss.getSheetByName("AppConfig");
  const rows = sheet.getDataRange().getValues();
  const platform = data.platform; // "Windows", "Android", atau "Extension"
  
  for (let i = 1; i < rows.length; i++) {
    if (rows[i][0] === platform) {
      return createResponse({
        status: "success",
        latest_version: rows[i][1], // Kolom B
        download_url: rows[i][2],   // Kolom C
        force_update: rows[i][3] === true // Kolom D
      });
    }
  }
  return createResponse({ status: "error", message: "Platform config not found" });
}

function handleSurvey(ss, data) {
  let sheet = ss.getSheetByName("SurveyResults");
  if (!sheet) {
    sheet = ss.insertSheet("SurveyResults");
    sheet.appendRow(["Timestamp", "Email", "Name", "Source"]);
  }
  
  sheet.appendRow([
    new Date(),
    data.email || "No Email",
    data.name || "No Name",
    data.source || "Unknown"
  ]);
  
  return createResponse({ status: "success", message: "Survey disimpan" });
}

// FUNGSI VALIDASI REAL-TIME (CEK APAKAH MASIH AKTIF/DIBLOKIR)
function handleValidation(ss, data) {
  const sheet = ss.getSheetByName("Licenses");
  const rows = sheet.getDataRange().getValues();
  const key = data.license_key;
  const deviceId = data.device_id;
  
  for (let i = 1; i < rows.length; i++) {
    if (rows[i][0] === key) { 
      // Cek Status (Kolom F - Index 5)
      if (rows[i][5] === "Blocked") {
        return createResponse({ status: "error", message: "Blocked", license_status: "Blocked" });
      }
      
      // Cek apakah device masih terdaftar (Kolom B dan D)
      const device1 = rows[i][1];
      const device2 = rows[i][3];
      
      if (device1 === deviceId || device2 === deviceId) {
        return createResponse({ status: "success", license_status: "Active" });
      } else {
        return createResponse({ status: "error", message: "Device mismatch", license_status: "Removed" });
      }
    }
  }
  
  // Jika tidak ditemukan sama sekali (Baris dihapus)
  return createResponse({ status: "error", message: "Not found", license_status: "Deleted" });
}

function createResponse(payload, code = 200) {
  return ContentService.createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}
