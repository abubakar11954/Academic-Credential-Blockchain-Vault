;; Academic Credentials Registry Smart Contract
;; A decentralized system for issuing and verifying academic credentials

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CREDENTIAL-EXISTS (err u102))
(define-constant ERR-CREDENTIAL-NOT-FOUND (err u103))
(define-constant ERR-INSTITUTION-NOT-APPROVED (err u104))
(define-constant ERR-CREDENTIAL-REVOKED (err u105))
(define-constant ERR-INVALID-INPUT (err u106))
(define-constant ERR-LIST-TOO-LONG (err u107))
(define-constant ERR-CONTRACT-PAUSED (err u108))
(define-constant ERR-CREDENTIAL-TYPE-INACTIVE (err u109))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-INSTITUTION-CREDENTIALS u1000)
(define-constant MAX-STUDENT-CREDENTIALS u100)
(define-constant MIN-CREDENTIAL-HASH-LENGTH u32)

;; Data variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var total-credentials-issued uint u0)
(define-data-var contract-paused bool false)
(define-data-var next-institution-id uint u1)

;; Data maps
(define-map approved-institutions 
    principal 
    {
        name: (string-ascii 100),
        institution-id: uint,
        approved-at: uint,
        approved-by: principal,
        active: bool,
        credentials-issued: uint,
        country: (string-ascii 50),
        institution-type: (string-ascii 30)
    }
)

(define-map credentials 
    (buff 32) 
    {
        issuer: principal,
        issued-at: uint,
        credential-type: (string-ascii 50),
        student-id: (string-ascii 100),
        student-name: (string-ascii 100),
        program-name: (string-ascii 150),
        graduation-date: (string-ascii 20),
        grade: (optional (string-ascii 10)),
        revoked: bool,
        revoked-at: (optional uint),
        revoked-reason: (optional (string-ascii 200))
    }
)

(define-map institution-credentials 
    principal 
    (list 1000 (buff 32))
)

(define-map student-credentials 
    (string-ascii 100) 
    (list 100 (buff 32))
)

(define-map credential-types 
    (string-ascii 50) 
    {
        active: bool,
        description: (string-ascii 200),
        added-at: uint,
        added-by: principal,
        requirements: (string-ascii 300)
    }
)

;; Private functions
(define-private (is-valid-credential-hash (hash (buff 32)))
    (is-eq (len hash) MIN-CREDENTIAL-HASH-LENGTH)
)

(define-private (is-non-empty-string (str (string-ascii 100)))
    (> (len str) u0)
)

(define-private (is-non-empty-string-200 (str (string-ascii 200)))
    (> (len str) u0)
)

(define-private (is-non-empty-string-150 (str (string-ascii 150)))
    (> (len str) u0)
)

(define-private (is-non-empty-string-50 (str (string-ascii 50)))
    (> (len str) u0)
)

(define-private (is-non-empty-string-30 (str (string-ascii 30)))
    (> (len str) u0)
)

(define-private (is-non-empty-string-20 (str (string-ascii 20)))
    (> (len str) u0)
)

(define-private (is-contract-active)
    (not (var-get contract-paused))
)

(define-private (is-valid-principal (addr principal))
    (not (is-eq addr 'SP000000000000000000002Q6VF78))
)

;; Read-only functions
(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (get-contract-status)
    {
        paused: (var-get contract-paused),
        total-credentials: (var-get total-credentials-issued),
        owner: (var-get contract-owner),
        next-institution-id: (var-get next-institution-id)
    }
)

(define-read-only (is-institution-approved (institution principal))
    (match (map-get? approved-institutions institution)
        institution-data (and (get active institution-data) (is-contract-active))
        false
    )
)

(define-read-only (get-credential (credential-hash (buff 32)))
    (map-get? credentials credential-hash)
)

(define-read-only (verify-credential (credential-hash (buff 32)))
    (if (is-valid-credential-hash credential-hash)
        (match (map-get? credentials credential-hash)
            credential-data 
            {
                valid: (and 
                    (not (get revoked credential-data))
                    (is-institution-approved (get issuer credential-data))
                    (is-contract-active)
                    (is-credential-type-active (get credential-type credential-data))
                ),
                issuer: (get issuer credential-data),
                issued-at: (get issued-at credential-data),
                credential-type: (get credential-type credential-data),
                student-name: (get student-name credential-data),
                program-name: (get program-name credential-data),
                graduation-date: (get graduation-date credential-data),
                revoked: (get revoked credential-data),
                revoked-reason: (get revoked-reason credential-data)
            }
            {
                valid: false,
                issuer: CONTRACT-OWNER,
                issued-at: u0,
                credential-type: "",
                student-name: "",
                program-name: "",
                graduation-date: "",
                revoked: false,
                revoked-reason: none
            }
        )
        {
            valid: false,
            issuer: CONTRACT-OWNER,
            issued-at: u0,
            credential-type: "",
            student-name: "",
            program-name: "",
            graduation-date: "",
            revoked: false,
            revoked-reason: none
        }
    )
)

(define-read-only (get-student-credentials (student-id (string-ascii 100)))
    (let 
        (
            (credential-list (default-to (list) (map-get? student-credentials student-id)))
        )
        {
            credentials: credential-list,
            count: (len credential-list),
            student-id: student-id
        }
    )
)

(define-read-only (get-institution-info (institution principal))
    (match (map-get? approved-institutions institution)
        institution-data
        (some {
            info: institution-data,
            total-credentials: (len (default-to (list) (map-get? institution-credentials institution))),
            is-approved: (get active institution-data)
        })
        none
    )
)

(define-read-only (get-credential-type (type-name (string-ascii 50)))
    (map-get? credential-types type-name)
)

(define-read-only (is-credential-type-active (type-name (string-ascii 50)))
    (match (map-get? credential-types type-name)
        type-data (get active type-data)
        false
    )
)

;; Admin functions
(define-public (add-credential-type 
    (type-name (string-ascii 50)) 
    (description (string-ascii 200))
    (requirements (string-ascii 300))
)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
        (asserts! (is-non-empty-string type-name) ERR-INVALID-INPUT)
        (asserts! (is-non-empty-string-200 description) ERR-INVALID-INPUT)
        
        (ok (map-set credential-types type-name {
            active: true,
            description: description,
            added-at: stacks-block-height,
            added-by: tx-sender,
            requirements: requirements
        }))
    )
)

(define-public (add-approved-institution 
    (institution principal) 
    (name (string-ascii 100))
    (country (string-ascii 50))
    (institution-type (string-ascii 30))
)
    (let
        (
            (current-id (var-get next-institution-id))
        )
        (begin
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
            (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
            (asserts! (is-valid-principal institution) ERR-INVALID-INPUT)
            (asserts! (is-non-empty-string name) ERR-INVALID-INPUT)
            (asserts! (is-non-empty-string-50 country) ERR-INVALID-INPUT)
            (asserts! (is-non-empty-string-30 institution-type) ERR-INVALID-INPUT)
            (asserts! (is-none (map-get? approved-institutions institution)) ERR-CREDENTIAL-EXISTS)
            
            (map-set approved-institutions institution {
                name: name,
                institution-id: current-id,
                approved-at: stacks-block-height,
                approved-by: tx-sender,
                active: true,
                credentials-issued: u0,
                country: country,
                institution-type: institution-type
            })
            
            (map-set institution-credentials institution (list))
            (var-set next-institution-id (+ current-id u1))
            
            (ok current-id)
        )
    )
)

(define-public (deactivate-institution (institution principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
        
        (match (map-get? approved-institutions institution)
            institution-data 
            (ok (map-set approved-institutions institution 
                (merge institution-data {active: false})))
            ERR-INSTITUTION-NOT-APPROVED
        )
    )
)

(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (ok (var-set contract-paused true))
    )
)

(define-public (resume-contract)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (ok (var-set contract-paused false))
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-principal new-owner) ERR-INVALID-INPUT)
        (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR-INVALID-INPUT)
        
        (ok (var-set contract-owner new-owner))
    )
)

;; Core credential functions
(define-public (issue-credential 
    (credential-hash (buff 32))
    (credential-type (string-ascii 50))
    (student-id (string-ascii 100))
    (student-name (string-ascii 100))
    (program-name (string-ascii 150))
    (graduation-date (string-ascii 20))
    (grade (optional (string-ascii 10)))
)
    (let 
        (
            (existing-credential (map-get? credentials credential-hash))
            (institution-creds (default-to (list) (map-get? institution-credentials tx-sender)))
            (student-creds (default-to (list) (map-get? student-credentials student-id)))
            (institution-data (unwrap! (map-get? approved-institutions tx-sender) ERR-INSTITUTION-NOT-APPROVED))
        )
        (begin
            (asserts! (is-institution-approved tx-sender) ERR-INSTITUTION-NOT-APPROVED)
            (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
            (asserts! (is-valid-credential-hash credential-hash) ERR-INVALID-INPUT)
            (asserts! (is-credential-type-active credential-type) ERR-CREDENTIAL-TYPE-INACTIVE)
            (asserts! (is-non-empty-string student-id) ERR-INVALID-INPUT)
            (asserts! (is-non-empty-string student-name) ERR-INVALID-INPUT)
            (asserts! (is-non-empty-string-150 program-name) ERR-INVALID-INPUT)
            (asserts! (is-non-empty-string-20 graduation-date) ERR-INVALID-INPUT)
            (asserts! (is-none existing-credential) ERR-CREDENTIAL-EXISTS)
            (asserts! (< (len institution-creds) MAX-INSTITUTION-CREDENTIALS) ERR-LIST-TOO-LONG)
            (asserts! (< (len student-creds) MAX-STUDENT-CREDENTIALS) ERR-LIST-TOO-LONG)
            
            (map-set credentials credential-hash {
                issuer: tx-sender,
                issued-at: stacks-block-height,
                credential-type: credential-type,
                student-id: student-id,
                student-name: student-name,
                program-name: program-name,
                graduation-date: graduation-date,
                grade: grade,
                revoked: false,
                revoked-at: none,
                revoked-reason: none
            })
            
            (map-set institution-credentials tx-sender 
                (unwrap! (as-max-len? (append institution-creds credential-hash) u1000) ERR-LIST-TOO-LONG))
            
            (map-set student-credentials student-id
                (unwrap! (as-max-len? (append student-creds credential-hash) u100) ERR-LIST-TOO-LONG))
            
            (map-set approved-institutions tx-sender
                (merge institution-data {
                    credentials-issued: (+ (get credentials-issued institution-data) u1)
                }))
            
            (var-set total-credentials-issued (+ (var-get total-credentials-issued) u1))
            
            (ok credential-hash)
        )
    )
)

(define-public (revoke-credential (credential-hash (buff 32)) (reason (string-ascii 200)))
    (match (map-get? credentials credential-hash)
        credential-data
        (begin
            (asserts! (is-eq tx-sender (get issuer credential-data)) ERR-NOT-AUTHORIZED)
            (asserts! (is-contract-active) ERR-CONTRACT-PAUSED)
            (asserts! (not (get revoked credential-data)) ERR-CREDENTIAL-REVOKED)
            (asserts! (is-non-empty-string-200 reason) ERR-INVALID-INPUT)
            
            (ok (map-set credentials credential-hash
                (merge credential-data {
                    revoked: true,
                    revoked-at: (some stacks-block-height),
                    revoked-reason: (some reason)
                })))
        )
        ERR-CREDENTIAL-NOT-FOUND
    )
)