#!/bin/bash
# Script to create sample tables and data in the CNPG cluster

NAMESPACE=default
CLUSTER_NAME=example1
SQL_FILE="/Users/satoru/lab/barman-cnpg/sql/create-sample-tables.sql"

echo "=== Creating Sample Tables and Data ==="
echo ""

# Check if cluster exists and is ready
echo "🔍 Checking cluster status..."
if kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    STATUS=$(kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    echo "✅ Cluster '$CLUSTER_NAME' found with status: $STATUS"
    
    if [ "$STATUS" != "Cluster in healthy state" ]; then
        echo "⚠️  Cluster is not in healthy state. Continuing anyway..."
    fi
else
    echo "❌ Cluster '$CLUSTER_NAME' not found in namespace '$NAMESPACE'"
    exit 1
fi
echo ""

# Get the primary pod
PRIMARY_POD=$(kubectl get pods -n "$NAMESPACE" -l cnpg.io/cluster="$CLUSTER_NAME",cnpg.io/instanceRole=primary -o jsonpath='{.items[0].metadata.name}')

if [ -z "$PRIMARY_POD" ]; then
    echo "❌ Could not find primary pod for cluster '$CLUSTER_NAME'"
    exit 1
fi

echo "📝 Found primary pod: $PRIMARY_POD"
echo ""

# Execute the SQL file
echo "🚀 Creating sample tables and data..."
if kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -- psql -U postgres -f - < "$SQL_FILE"; then
    echo "✅ Sample tables and data created successfully!"
else
    echo "❌ Failed to create sample tables and data"
    exit 1
fi
echo ""

# Force a checkpoint to ensure WAL consistency
echo "💾 Forcing database checkpoint for WAL consistency..."
kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -- psql -U postgres -c "CHECKPOINT;"
echo ""

# Show database activity
echo "📊 Database statistics:"
kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -- psql -U postgres -c "
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY n_tup_ins DESC;
"
echo ""

# Show WAL activity
echo "📈 WAL (Write-Ahead Log) activity:"
kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -- psql -U postgres -c "
SELECT 
    pg_current_wal_lsn() as current_wal_lsn,
    pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') as wal_bytes_generated;
"
echo ""

echo "🎉 Sample data creation completed!"
echo ""
echo "🔧 Next steps:"
echo "   1. Take a backup: ./31-manual-backup.sh"
echo "   2. Wait a few minutes for WAL archiving"
echo "   3. Try restore: ./33-restore-from-s3.sh"
echo ""
echo "💡 You can now connect to the database and explore:"
echo "   kubectl exec -it $PRIMARY_POD -n $NAMESPACE -- psql -U postgres"
