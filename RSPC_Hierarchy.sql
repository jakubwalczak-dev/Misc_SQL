WITH "CTE" AS
(
	SELECT
		T1.CHAIN_ID
		, T1.EVENT_START
		, T1.EVENTP_START
		, T1.EVENTP_GREEN
		, T1.TYPE
		, T1.VARIANTE
	FROM
		"SAPABAP1"."RSPCCHAIN" T1
	WHERE
		T1.OBJVERS         = 'A'
		AND T1.CHAIN_ID like 'Z%'
	ORDER BY
		T1.CHAIN_ID
		, T1.EVENT_START
		, T1.EVENTP_START
)
, "HIER" AS
(
	SELECT
		"HIERARCHY_RANK"
		, "HIERARCHY_TREE_SIZE"
		, "HIERARCHY_PARENT_RANK"
		, "HIERARCHY_ROOT_RANK"
		, "HIERARCHY_LEVEL"
		, "HIERARCHY_IS_CYCLE"
		, "HIERARCHY_IS_ORPHAN"
		, "CHAIN_ID"
		, "EVENT_START"
		, "EVENTP_START"
		, "EVENTP_GREEN"
		, "TYPE"
		, "VARIANTE"
		, "NODE_ID"
		, "PARENT_ID"
	FROM
		HIERARCHY ( SOURCE
		(
			SELECT   *
				, EVENTP_GREEN node_id
				, EVENTP_START parent_id
			FROM
				CTE
		)
		START WHERE EVENTP_START = '' ORPHAN IGNORE )
)
, "RSPC_HIERARCHY" AS
(
	SELECT
		CHAIN_ID
		, EVENT_START
		, EVENTP_START
		, EVENTP_GREEN
		, TYPE
		, VARIANTE
		, NODE_ID
		, PARENT_ID
		, hierarchy_rank
	FROM
		(
			SELECT   *
			FROM
				HIER
			ORDER BY
				CHAIN_ID
				, hierarchy_rank
				, hierarchy_tree_size
		)
	WHERE
		(
			"HIERARCHY_ROOT_RANK"     = '1'
			--AND "HIERARCHY_IS_CYCLE" <> '1'
		)
)
, "PC_TGT_ORDER" AS
(
	SELECT
		"CHAIN_ID"
		, LAG(CHAIN_ID) OVER ( ORDER BY "CHAIN_ID" ASC , "HIERARCHY_RANK" ASC) LAG_CHAIN_ID
		, DENSE_RANK() OVER ( ORDER BY CHAIN_ID )                              CHAIN_NO
		, "VARIANTE"
		, ROW_NUMBER() OVER ( ORDER BY "CHAIN_ID" ASC , "HIERARCHY_RANK" ASC) ROW_NUMBER
		, T1."TGT"                                                            TARGET
		, ROW_NUMBER() OVER ( PARTITION BY T1.TGT, CHAIN_ID ORDER BY
							 "CHAIN_ID" ASC , "HIERARCHY_RANK" ASC)            TARGET_NO
		, LAG(T1."TGT") OVER ( ORDER BY "CHAIN_ID" ASC , "HIERARCHY_RANK" ASC) LAG_TARGET
		, HIERARCHY_RANK
	FROM
		"RSPC_HIERARCHY"
		LEFT JOIN
			(
				SELECT   *
				FROM
					"SAPABAP1"."RSBKDTP"
				WHERE
					(
						"OBJVERS" = 'A'
					)
			)
			T1
			ON
				RSPC_HIERARCHY.VARIANTE = T1.DTP
	ORDER BY
		"CHAIN_ID" ASC --, "VARIANTE" ASC
		, "HIERARCHY_RANK" ASC
)
SELECT
	CHAIN_ID
	, CHAIN_NO
	, VARIANTE
	, ROW_NUMBER
	, TARGET --, TARGET_NO
	, CASE
		WHEN (
				(
					TARGET      <> LAG_TARGET
					OR CHAIN_ID <> LAG_CHAIN_ID
				)
				OR LAG_TARGET is null
			)
			THEN ROW_NUMBER
			ELSE ROW_NUMBER - TARGET_NO + 1
	END as TGT_NO
	, HIERARCHY_RANK
FROM
	PC_TGT_ORDER
ORDER BY
	HIERARCHY_RANK
	, CHAIN_NO
	, TGT_NO