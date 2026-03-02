import argparse
import subprocess
import datetime
import os
import tempfile
import json

def run_command(command):
    result = subprocess.run(
        command,
        shell=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    if result.returncode != 0:
        raise Exception(result.stderr)
    return result.stdout.strip()

def is_container_running(container_name):
    try:
        output = run_command(
            f"docker inspect -f '{{{{.State.Running}}}}' {container_name}"
        )
        return output.lower() == "true"
    except Exception:
        return False

def get_container_env(container_name):
    """
    Return container environment variables as dict
    """
    output = run_command(
        f"docker inspect {container_name}"
    )
    data = json.loads(output)[0]
    env_list = data["Config"]["Env"]
    env_dict = {}
    for item in env_list:
        if "=" in item:
            k, v = item.split("=", 1)
            env_dict[k] = v
    return env_dict

def resolve_db_config(args, envs):
    """
    Resolve db_name, db_user, db_password
    Priority: CLI args > container env > error
    """
    if args.db_type == "postgres":
        db_name = args.db_name or envs.get("POSTGRES_DB")
        db_user = args.db_user or envs.get("POSTGRES_USER")
        db_password = args.db_password or envs.get("POSTGRES_PASSWORD")

    elif args.db_type == "mysql":
        db_name = args.db_name or envs.get("MYSQL_DATABASE")
        db_user = args.db_user or envs.get("MYSQL_USER") or "root"
        db_password = (
            args.db_password
            or envs.get("MYSQL_PASSWORD")
            or envs.get("MYSQL_ROOT_PASSWORD")
        )

    elif args.db_type == "mongodb":
        db_name = args.db_name or envs.get("MONGO_INITDB_DATABASE")
        db_user = args.db_user or envs.get("MONGO_INITDB_ROOT_USERNAME")
        db_password = args.db_password or envs.get("MONGO_INITDB_ROOT_PASSWORD")

    else:
        raise Exception("Unsupported DB type")

    if not all([db_name, db_user, db_password]):
        raise Exception(
            f"Missing database config. "
            f"db_name={db_name}, db_user={db_user}, db_password={'***' if db_password else None}"
        )

    return db_name, db_user, db_password

def backup_database(db_type, container, db_name, db_user, db_password, backup_file):
    if db_type == "postgres":
        cmd = (
            f"docker exec {container} "
            f"pg_dump -U {db_user} {db_name} "
            f"| gzip > {backup_file}"
        )

    elif db_type == "mysql":
        cmd = (
            f"docker exec {container} sh -c "
            f"\"mysqldump -u{db_user} -p'{db_password}' {db_name}\" "
            f"| gzip > {backup_file}"
        )

    elif db_type == "mongodb":
        cmd = (
            f"docker exec {container} "
            f"mongodump --username {db_user} "
            f"--password {db_password} "
            f"--db {db_name} "
            f"--authenticationDatabase admin --archive "
            f"| gzip > {backup_file}"
        )

    else:
        raise Exception("Unsupported database type")

    print(f"[+] Backup command:\n{cmd}")
    run_command(cmd)

def upload_to_remote(backup_file, remote_path):
    cmd = f"rclone copy {backup_file} {remote_path}"
    print(f"[+] Uploading backup:\n{cmd}")
    run_command(cmd)

def apply_retention(remote_path, retention):
    files = run_command(f"rclone lsf {remote_path}").splitlines()
    files = sorted([f for f in files if f.strip()])

    if len(files) > retention:
        for old in files[:-retention]:
            print(f"[+] Deleting old backup: {old}")
            run_command(f"rclone delete {remote_path}/{old}")

def main():
    parser = argparse.ArgumentParser(description="Container DB backup with env fallback")
    parser.add_argument("--container", required=True)
    parser.add_argument("--db-type", required=True, choices=["postgres", "mysql", "mongodb"])
    parser.add_argument("--db-name")
    parser.add_argument("--db-user")
    parser.add_argument("--db-password")
    parser.add_argument("--remote", required=True)
    parser.add_argument("--retention", type=int, default=7)

    args = parser.parse_args()

    if not is_container_running(args.container):
        print(f"[!] Container {args.container} is not running")
        return

    envs = get_container_env(args.container)
    db_name, db_user, db_password = resolve_db_config(args, envs)

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{db_name}_{timestamp}.sql.gz"
    backup_file = os.path.join(tempfile.gettempdir(), filename)

    try:
        backup_database(
            args.db_type,
            args.container,
            db_name,
            db_user,
            db_password,
            backup_file
        )
        upload_to_remote(backup_file, args.remote)
        apply_retention(args.remote, args.retention)
    finally:
        if os.path.exists(backup_file):
            os.remove(backup_file)

if __name__ == "__main__":
    main()