#!/usr/bin/env python3
"""
Backup Server - Flask application for receiving and managing backups
Supports: upload, download, list, verify backups from shell scripts
"""

from flask import Flask, request, jsonify, send_file
import os
import json
from pathlib import Path
from datetime import datetime
import hashlib

app = Flask(__name__)

BASE_DIR = Path(__file__).parent
REMOTE_BACKUPS_DIR = BASE_DIR / "remote_backups"
UPLOAD_DIR = REMOTE_BACKUPS_DIR
MAX_FILE_SIZE = 500 * 1024 * 1024

for backup_type in ["FULL", "INC", "DIFF"]:
    (REMOTE_BACKUPS_DIR / backup_type).mkdir(parents=True, exist_ok=True)


def calculate_file_hash(filepath, algorithm="md5"):
    """Calculate hash of a file"""
    hash_func = hashlib.new(algorithm)
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_func.update(chunk)
    return hash_func.hexdigest()


def get_file_info(filepath):
    """Get information about a file"""
    stat = filepath.stat()
    return {
        "name": filepath.name,
        "size": stat.st_size,
        "size_human": format_size(stat.st_size),
        "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
        "md5": calculate_file_hash(filepath)
    }


def format_size(bytes_size):
    """Format bytes to human readable format"""
    for unit in ["B", "KB", "MB", "GB"]:
        if bytes_size < 1024:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024
    return f"{bytes_size:.1f} TB"


@app.route("/", methods=["GET"])
def index():
    """Root endpoint - API information"""
    return jsonify({
        "name": "Backup Server",
        "version": "1.0.0",
        "description": "Web server for backup synchronization",
        "endpoints": {
            "POST /upload": "Upload a backup file",
            "GET /list": "List all backups",
            "GET /list/<type>": "List backups of specific type (FULL|INC|DIFF)",
            "GET /download/<type>/<filename>": "Download a specific backup file",
            "POST /verify": "Verify backup synchronization",
            "GET /stats": "Get server statistics"
        }
    })


@app.route("/upload", methods=["POST"])
def upload():
    """
    Upload a backup file
    Expects:
        - file: the backup archive (tar.gz)
        - type: backup type (FULL, INC, DIFF)
        - profile: profile name (optional)
    """
    try:
        if "file" not in request.files:
            return jsonify({"error": "No file provided"}), 400

        file = request.files["file"]
        backup_type = request.form.get("type", "FULL").upper()

        if backup_type not in ["FULL", "INC", "DIFF"]:
            return jsonify({"error": f"Invalid backup type: {backup_type}"}), 400

        if not file.filename or not file.filename.endswith(".tar.gz"):
            return jsonify({"error": "File must be a .tar.gz archive"}), 400

        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)

        if file_size > MAX_FILE_SIZE:
            return jsonify({"error": f"File size exceeds limit ({MAX_FILE_SIZE} bytes)"}), 413

        upload_dir = REMOTE_BACKUPS_DIR / backup_type
        upload_dir.mkdir(parents=True, exist_ok=True)
        
        filepath = upload_dir / file.filename
        file.save(str(filepath))

        file_info = get_file_info(filepath)
        metadata = {
            "filename": file.filename,
            "type": backup_type,
            "profile": request.form.get("profile", "unknown"),
            "uploaded_at": datetime.now().isoformat(),
            **file_info
        }

        metadata_path = filepath.with_suffix(".json")
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2)

        return jsonify({
            "status": "success",
            "message": f"File uploaded successfully",
            "file": file.filename,
            "type": backup_type,
            "size": file_info["size_human"],
            "md5": file_info["md5"]
        }), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/list", methods=["GET"])
def list_backups():
    """List all backups or backups of a specific type"""
    try:
        backup_type = request.args.get("type", None)
        result = {}

        types_to_check = [backup_type.upper()] if backup_type else ["FULL", "INC", "DIFF"]

        for btype in types_to_check:
            type_dir = REMOTE_BACKUPS_DIR / btype
            if not type_dir.exists():
                result[btype] = []
                continue

            backups = []
            for archive in sorted(type_dir.glob("*.tar.gz")):
                info = get_file_info(archive)
                
                metadata_path = archive.with_suffix(".json")
                if metadata_path.exists():
                    with open(metadata_path, "r") as f:
                        metadata = json.load(f)
                    info.update(metadata)

                backups.append(info)

            result[btype] = backups

        return jsonify({
            "status": "success",
            "backups": result,
            "total_count": sum(len(v) for v in result.values())
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/list/<backup_type>", methods=["GET"])
def list_backups_by_type(backup_type):
    """List backups of a specific type"""
    try:
        backup_type = backup_type.upper()
        
        if backup_type not in ["FULL", "INC", "DIFF"]:
            return jsonify({"error": f"Invalid backup type: {backup_type}"}), 400

        type_dir = REMOTE_BACKUPS_DIR / backup_type
        backups = []

        if type_dir.exists():
            for archive in sorted(type_dir.glob("*.tar.gz")):
                info = get_file_info(archive)
                
                metadata_path = archive.with_suffix(".json")
                if metadata_path.exists():
                    with open(metadata_path, "r") as f:
                        metadata = json.load(f)
                    info.update(metadata)

                backups.append(info)

        return jsonify({
            "status": "success",
            "type": backup_type,
            "backups": backups,
            "count": len(backups)
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/download/<backup_type>/<filename>", methods=["GET"])
def download_backup(backup_type, filename):
    """
    Download a specific backup file
    """
    try:
        backup_type = backup_type.upper()
        
        if backup_type not in ["FULL", "INC", "DIFF"]:
            return jsonify({"error": f"Invalid backup type: {backup_type}"}), 400
        
        file_path = REMOTE_BACKUPS_DIR / backup_type / filename
        
        if not file_path.exists():
            return jsonify({"error": "File not found"}), 404
        
        if not filename.endswith(".tar.gz"):
            return jsonify({"error": "Only .tar.gz files can be downloaded"}), 400
        
        return send_file(str(file_path), as_attachment=True, download_name=filename)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/verify", methods=["POST"])
def verify_sync():
    """
    Verify backup synchronization
    Compare local and remote backups
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400

        local_backups = data.get("local_backups", {})
        result = {
            "status": "success",
            "verification": {},
            "sync_status": "unknown",
            "issues": []
        }

        remote_backups = {}
        for btype in ["FULL", "INC", "DIFF"]:
            remote_backups[btype] = []
            type_dir = REMOTE_BACKUPS_DIR / btype
            if type_dir.exists():
                for archive in type_dir.glob("*.tar.gz"):
                    remote_backups[btype].append({
                        "name": archive.name,
                        "size": archive.stat().st_size,
                        "md5": calculate_file_hash(archive)
                    })

        for btype in ["FULL", "INC", "DIFF"]:
            local_list = local_backups.get(btype, [])
            remote_list = remote_backups.get(btype, [])

            verification = {
                "type": btype,
                "local_count": len(local_list),
                "remote_count": len(remote_list),
                "synced": [],
                "missing_remote": [],
                "extra_remote": []
            }

            for local_file in local_list:
                found = False
                for remote_file in remote_list:
                    if local_file.get("name") == remote_file.get("name"):
                        if local_file.get("md5") == remote_file.get("md5"):
                            verification["synced"].append(local_file["name"])
                            found = True
                            break
                
                if not found:
                    verification["missing_remote"].append(local_file["name"])
                    result["issues"].append(f"Missing on remote: {btype}/{local_file['name']}")

            for remote_file in remote_list:
                found = False
                for local_file in local_list:
                    if remote_file.get("name") == local_file.get("name"):
                        found = True
                        break
                
                if not found:
                    verification["extra_remote"].append(remote_file["name"])

            result["verification"][btype] = verification

        all_synced = all(
            v["missing_remote"] == [] and v["local_count"] == v["remote_count"]
            for v in result["verification"].values()
        )
        result["sync_status"] = "SYNCHRONIZED" if all_synced else "OUT_OF_SYNC"

        return jsonify(result), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/stats", methods=["GET"])
def get_stats():
    """Get server statistics"""
    try:
        stats = {
            "status": "success",
            "timestamp": datetime.now().isoformat(),
            "storage": {}
        }

        total_size = 0
        total_files = 0

        for btype in ["FULL", "INC", "DIFF"]:
            type_dir = REMOTE_BACKUPS_DIR / btype
            size = 0
            count = 0

            if type_dir.exists():
                for archive in type_dir.glob("*.tar.gz"):
                    size += archive.stat().st_size
                    count += 1

            stats["storage"][btype] = {
                "count": count,
                "size": size,
                "size_human": format_size(size)
            }

            total_size += size
            total_files += count

        stats["total"] = {
            "files": total_files,
            "size": total_size,
            "size_human": format_size(total_size)
        }

        return jsonify(stats), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    print("=" * 60)
    print("Backup Server - Flask Application")
    print("=" * 60)
    print(f"Remote backups directory: {REMOTE_BACKUPS_DIR}")
    print("Starting server on http://localhost:5000")
    print("=" * 60)
    app.run(debug=True, host="0.0.0.0", port=5000)