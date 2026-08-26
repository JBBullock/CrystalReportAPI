--
-- PostgreSQL database dump
--

\restrict 1Mg1Weq1Ys9sBXKSrbcU3wvf1S42eBfyN5X3rvA8Zirb9SxDngN7v7eTK2fCnOr

-- Dumped from database version 18.3 (Debian 18.3-1.pgdg13+1)
-- Dumped by pg_dump version 18.3 (Debian 18.3-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: audit_audit_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_audit_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_audit_pkey_seq OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit (
    audfile character varying(5000),
    audkey character varying(5000),
    audfield character varying(5000),
    auddate character varying(5000),
    audtime character varying(5000),
    audwasl character varying(5000),
    audwasn character varying(5000),
    audisl character varying(5000),
    audisn character varying(5000),
    auduser character varying(5000),
    audit_pkey character varying(5000) DEFAULT nextval('public.audit_audit_pkey_seq'::regclass)
);


ALTER TABLE public.audit OWNER TO postgres;

--
-- Name: bom_bom_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bom_bom_pkey_seq
    START WITH 63
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bom_bom_pkey_seq OWNER TO postgres;

--
-- Name: bom; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bom (
    assembly character varying(5000),
    component character varying(5000),
    itemsequence integer,
    quantityper real,
    effectivedate character varying(5000),
    obsoletedate character varying(5000),
    bomuomcode character varying(5000),
    notes character varying(5000),
    bom_pkey integer DEFAULT nextval('public.bom_bom_pkey_seq'::regclass)
);


ALTER TABLE public.bom OWNER TO postgres;

--
-- Name: calendar_calendar_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.calendar_calendar_pkey_seq
    START WITH 19
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.calendar_calendar_pkey_seq OWNER TO postgres;

--
-- Name: calendar; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.calendar (
    desctext character varying(5000),
    startdate character varying(5000),
    enddate character varying(5000),
    calendar_pkey integer DEFAULT nextval('public.calendar_calendar_pkey_seq'::regclass)
);


ALTER TABLE public.calendar OWNER TO postgres;

--
-- Name: commoditycodes_commoditycodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.commoditycodes_commoditycodes_pkey_seq
    START WITH 14
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.commoditycodes_commoditycodes_pkey_seq OWNER TO postgres;

--
-- Name: commoditycodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.commoditycodes (
    commoditycode character varying(5000),
    desctext character varying(5000),
    employeeid character varying(5000),
    commoditycodes_pkey integer DEFAULT nextval('public.commoditycodes_commoditycodes_pkey_seq'::regclass)
);


ALTER TABLE public.commoditycodes OWNER TO postgres;

--
-- Name: company_company_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.company_company_pkey_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.company_company_pkey_seq OWNER TO postgres;

--
-- Name: company; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.company (
    companyname character varying(5000),
    contact1 character varying(5000),
    contact2 character varying(5000),
    email character varying(5000),
    regioncode character varying(5000),
    vatregnumber character varying(5000),
    vatbranchid character varying(5000),
    company_pkey integer DEFAULT nextval('public.company_company_pkey_seq'::regclass),
    phone1 character varying(5000),
    phone1fmt character varying(5000),
    phone2 character varying(5000),
    phone2fmt character varying(5000),
    fax character varying(5000),
    faxfmt character varying(5000)
);


ALTER TABLE public.company OWNER TO postgres;

--
-- Name: companyaddress_companyaddress_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.companyaddress_companyaddress_pkey_seq
    START WITH 7
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.companyaddress_companyaddress_pkey_seq OWNER TO postgres;

--
-- Name: companyaddress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.companyaddress (
    addressid character varying(5000),
    addressline1 character varying(5000),
    addressline2 character varying(5000),
    addressline3 character varying(5000),
    addressline4 character varying(5000),
    city character varying(5000),
    state character varying(5000),
    zipcode integer,
    postal character varying(5000),
    country character varying(5000),
    shiptoflag boolean,
    billtoflag boolean,
    taxcode character varying(5000),
    companyaddress_pkey integer DEFAULT nextval('public.companyaddress_companyaddress_pkey_seq'::regclass)
);


ALTER TABLE public.companyaddress OWNER TO postgres;

--
-- Name: creditmemodetail_creditmemodetail_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.creditmemodetail_creditmemodetail_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.creditmemodetail_creditmemodetail_pkey_seq OWNER TO postgres;

--
-- Name: creditmemodetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.creditmemodetail (
    creditmemonumber character varying(5000),
    creditmemoline character varying(5000),
    sonumber character varying(5000),
    soline character varying(5000),
    partnumber character varying(5000),
    quantity character varying(5000),
    price character varying(5000),
    salesuom character varying(5000),
    taxableflag character varying(5000),
    taxcode2 character varying(5000),
    taxrate2 character varying(5000),
    taxflag2 character varying(5000),
    taxcode3 character varying(5000),
    taxrate3 character varying(5000),
    taxflag3 character varying(5000),
    basetaxcode character varying(5000),
    basetaxrate character varying(5000),
    creditmemodetail_pkey character varying(5000) DEFAULT nextval('public.creditmemodetail_creditmemodetail_pkey_seq'::regclass)
);


ALTER TABLE public.creditmemodetail OWNER TO postgres;

--
-- Name: creditmemoheader_creditmemoheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.creditmemoheader_creditmemoheader_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.creditmemoheader_creditmemoheader_pkey_seq OWNER TO postgres;

--
-- Name: creditmemoheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.creditmemoheader (
    creditmemonumber character varying(5000),
    invoicenumber character varying(5000),
    customerid character varying(5000),
    sonumber character varying(5000),
    enteredby character varying(5000),
    returndate character varying(5000),
    freightamount character varying(5000),
    trackingnumber character varying(5000),
    numberofpieces character varying(5000),
    weight character varying(5000),
    carrier character varying(5000),
    billoflading character varying(5000),
    notes character varying(5000),
    userdefined1 character varying(5000),
    userdefined2 character varying(5000),
    taxcode2 character varying(5000),
    taxcode3 character varying(5000),
    basetaxcode character varying(5000),
    creditmemoheader_pkey character varying(5000) DEFAULT nextval('public.creditmemoheader_creditmemoheader_pkey_seq'::regclass)
);


ALTER TABLE public.creditmemoheader OWNER TO postgres;

--
-- Name: crpdetail_crpdetail_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crpdetail_crpdetail_pkey_seq
    START WITH 1148
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.crpdetail_crpdetail_pkey_seq OWNER TO postgres;

--
-- Name: crpdetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crpdetail (
    wonumber character varying(5000),
    sequenceid integer,
    operationcode character varying(5000),
    startdatetime character varying(5000),
    workcenterid character varying(5000),
    shiftid character varying(5000),
    partnumber character varying(5000),
    startquantity real,
    minutesused real,
    stopdatetime character varying(5000),
    summarydate character varying(5000),
    crpdetail_pkey integer DEFAULT nextval('public.crpdetail_crpdetail_pkey_seq'::regclass)
);


ALTER TABLE public.crpdetail OWNER TO postgres;

--
-- Name: crpheader_crpheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crpheader_crpheader_pkey_seq
    START WITH 71
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.crpheader_crpheader_pkey_seq OWNER TO postgres;

--
-- Name: crpheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crpheader (
    workcenterid character varying(5000),
    laborscheduled boolean,
    overcapacity boolean,
    crpheader_pkey integer DEFAULT nextval('public.crpheader_crpheader_pkey_seq'::regclass)
);


ALTER TABLE public.crpheader OWNER TO postgres;

--
-- Name: crpsummary_crpsummary_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crpsummary_crpsummary_pkey_seq
    START WITH 578
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.crpsummary_crpsummary_pkey_seq OWNER TO postgres;

--
-- Name: crpsummary; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crpsummary (
    workcenterid character varying(5000),
    startdate character varying(5000),
    capusage real,
    capacity real,
    crpsummary_pkey integer DEFAULT nextval('public.crpsummary_crpsummary_pkey_seq'::regclass)
);


ALTER TABLE public.crpsummary OWNER TO postgres;

--
-- Name: currencycodes_currencycodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.currencycodes_currencycodes_pkey_seq
    START WITH 29
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.currencycodes_currencycodes_pkey_seq OWNER TO postgres;

--
-- Name: currencycodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.currencycodes (
    currencycode character varying(5000),
    exchangerate real,
    desctext character varying(5000),
    eurorate real,
    emumember boolean,
    currencycodes_pkey integer DEFAULT nextval('public.currencycodes_currencycodes_pkey_seq'::regclass),
    currencysymbol character varying(5000)
);


ALTER TABLE public.currencycodes OWNER TO postgres;

--
-- Name: customeraddress_customeraddress_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customeraddress_customeraddress_pkey_seq
    START WITH 53
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customeraddress_customeraddress_pkey_seq OWNER TO postgres;

--
-- Name: customeraddress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customeraddress (
    customerid character varying(5000),
    addressid character varying(5000),
    addressline1 character varying(5000),
    addressline2 character varying(5000),
    addressline3 character varying(5000),
    addressline4 character varying(5000),
    city character varying(5000),
    state character varying(5000),
    zipcode integer,
    postal character varying(5000),
    country character varying(5000),
    shiptoflag boolean,
    billtoflag boolean,
    taxcode character varying(5000),
    customeraddress_pkey integer DEFAULT nextval('public.customeraddress_customeraddress_pkey_seq'::regclass)
);


ALTER TABLE public.customeraddress OWNER TO postgres;

--
-- Name: customercontacts_customercontacts_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customercontacts_customercontacts_pkey_seq
    START WITH 88
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customercontacts_customercontacts_pkey_seq OWNER TO postgres;

--
-- Name: customercontacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customercontacts (
    customerid character varying(5000),
    addressid character varying(5000),
    contactid character varying(5000),
    name character varying(5000),
    email character varying(5000),
    notes character varying(5000),
    customercontacts_pkey integer DEFAULT nextval('public.customercontacts_customercontacts_pkey_seq'::regclass),
    phone character varying(5000),
    phonefmt character varying(5000),
    fax character varying(5000),
    faxfmt character varying(5000)
);


ALTER TABLE public.customercontacts OWNER TO postgres;

--
-- Name: customerdisclevel_customerdisclevel_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customerdisclevel_customerdisclevel_pkey_seq
    START WITH 8
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customerdisclevel_customerdisclevel_pkey_seq OWNER TO postgres;

--
-- Name: customerdisclevel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customerdisclevel (
    customerdisclevel character varying(5000),
    desctext character varying(5000),
    customerdisclevel_pkey integer DEFAULT nextval('public.customerdisclevel_customerdisclevel_pkey_seq'::regclass)
);


ALTER TABLE public.customerdisclevel OWNER TO postgres;

--
-- Name: customers_customers_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customers_customers_pkey_seq
    START WITH 23
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_customers_pkey_seq OWNER TO postgres;

--
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    customerid character varying(5000),
    customername character varying(5000),
    pricecode character varying(5000),
    regioncode character varying(5000),
    shipholdflag boolean,
    termscode character varying(5000),
    shipviacode character varying(5000),
    fobcode character varying(5000),
    currencycode character varying(5000),
    vatregnumber character varying(5000),
    vatbranchid character varying(5000),
    dateadded character varying(5000),
    notes character varying(5000),
    activeflag boolean,
    creditlimit real,
    pricedisctype real,
    customerdisclevel character varying(5000),
    userdefined1 character varying(5000),
    salespersonid character varying(5000),
    customers_pkey integer DEFAULT nextval('public.customers_customers_pkey_seq'::regclass)
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- Name: datadefinitions_datadefinitions_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.datadefinitions_datadefinitions_pkey_seq
    START WITH 31336
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.datadefinitions_datadefinitions_pkey_seq OWNER TO postgres;

--
-- Name: datadefinitions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datadefinitions (
    name character varying(5000),
    author character varying(5000),
    version character varying(5000),
    controlname character varying(5000),
    propertybag character varying(5000),
    checkoutname character varying(5000),
    datadefinitions_pkey integer DEFAULT nextval('public.datadefinitions_datadefinitions_pkey_seq'::regclass),
    versionnumber integer
);


ALTER TABLE public.datadefinitions OWNER TO postgres;

--
-- Name: datautilitybatches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datautilitybatches (
    id character varying(5000),
    datatype character varying(5000),
    name character varying(5000),
    bindata character varying(5000)
);


ALTER TABLE public.datautilitybatches OWNER TO postgres;

--
-- Name: densitycodes_densitycodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.densitycodes_densitycodes_pkey_seq
    START WITH 8
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.densitycodes_densitycodes_pkey_seq OWNER TO postgres;

--
-- Name: densitycodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.densitycodes (
    densitycode character varying(5000),
    lengthfactor real,
    weightfactor real,
    volumefactor real,
    areafactor real,
    desctext character varying(5000),
    densitycodes_pkey integer DEFAULT nextval('public.densitycodes_densitycodes_pkey_seq'::regclass)
);


ALTER TABLE public.densitycodes OWNER TO postgres;

--
-- Name: departmentcodes_departmentcodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.departmentcodes_departmentcodes_pkey_seq
    START WITH 55
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.departmentcodes_departmentcodes_pkey_seq OWNER TO postgres;

--
-- Name: departmentcodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departmentcodes (
    departmentcode character varying(5000),
    desctext character varying(5000),
    accountnumber integer,
    nettableflag boolean,
    inventoryflag boolean,
    departmentcodes_pkey integer DEFAULT nextval('public.departmentcodes_departmentcodes_pkey_seq'::regclass)
);


ALTER TABLE public.departmentcodes OWNER TO postgres;

--
-- Name: ecnclasscodes_ecnclasscodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ecnclasscodes_ecnclasscodes_pkey_seq
    START WITH 11
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ecnclasscodes_ecnclasscodes_pkey_seq OWNER TO postgres;

--
-- Name: ecnclasscodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ecnclasscodes (
    ecnclasscode character varying(5000),
    desctext character varying(5000),
    ecnclasscodes_pkey integer DEFAULT nextval('public.ecnclasscodes_ecnclasscodes_pkey_seq'::regclass)
);


ALTER TABLE public.ecnclasscodes OWNER TO postgres;

--
-- Name: ecnheader_ecnheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ecnheader_ecnheader_pkey_seq
    START WITH 13
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ecnheader_ecnheader_pkey_seq OWNER TO postgres;

--
-- Name: ecnheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ecnheader (
    ecnnumber character varying(5000),
    ecnclasscode character varying(5000),
    ecndate character varying(5000),
    notes character varying(5000),
    employeeid character varying(5000),
    ecnheader_pkey integer DEFAULT nextval('public.ecnheader_ecnheader_pkey_seq'::regclass)
);


ALTER TABLE public.ecnheader OWNER TO postgres;

--
-- Name: ecnparts_ecnparts_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ecnparts_ecnparts_pkey_seq
    START WITH 41
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ecnparts_ecnparts_pkey_seq OWNER TO postgres;

--
-- Name: ecnparts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ecnparts (
    ecnnumber character varying(5000),
    partnumber character varying(5000),
    desctext character varying(5000),
    ecnparts_pkey integer DEFAULT nextval('public.ecnparts_ecnparts_pkey_seq'::regclass)
);


ALTER TABLE public.ecnparts OWNER TO postgres;

--
-- Name: employees_employees_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.employees_employees_pkey_seq
    START WITH 30
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.employees_employees_pkey_seq OWNER TO postgres;

--
-- Name: employees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employees (
    employeeid character varying(5000),
    departmentcode character varying(5000),
    ssn integer,
    firstname character varying(5000),
    middleinitial character varying(5000),
    lastname character varying(5000),
    suffix character varying(5000),
    addressline1 character varying(5000),
    addressline2 character varying(5000),
    city character varying(5000),
    state character varying(5000),
    zip integer,
    email character varying(5000),
    wagerate real,
    postal character varying(5000),
    country character varying(5000),
    issales boolean,
    ispurchasing boolean,
    islabor boolean,
    isecn boolean,
    istransactions boolean,
    notes character varying(5000),
    commissionrate real,
    active boolean,
    propertybag character varying(5000),
    employees_pkey integer DEFAULT nextval('public.employees_employees_pkey_seq'::regclass),
    phone character varying(5000),
    phonefmt character varying(5000),
    fax character varying(5000),
    faxfmt character varying(5000),
    permission_level integer,
    CONSTRAINT employees_permission_level_check CHECK (((permission_level >= 1) AND (permission_level <= 4)))
);


ALTER TABLE public.employees OWNER TO postgres;

--
-- Name: employeesectiondetail_employeesectiondetail_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.employeesectiondetail_employeesectiondetail_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.employeesectiondetail_employeesectiondetail_pkey_seq OWNER TO postgres;

--
-- Name: employeesectiondetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employeesectiondetail (
    employeeid character varying(5000),
    sectionname character varying(5000),
    detailname character varying(5000),
    rights character varying(5000),
    employeesectiondetail_pkey character varying(5000) DEFAULT nextval('public.employeesectiondetail_employeesectiondetail_pkey_seq'::regclass)
);


ALTER TABLE public.employeesectiondetail OWNER TO postgres;

--
-- Name: employeesections_employeesections_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.employeesections_employeesections_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.employeesections_employeesections_pkey_seq OWNER TO postgres;

--
-- Name: employeesections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employeesections (
    employeeid character varying(5000),
    sectionname character varying(5000),
    rights character varying(5000),
    employeesections_pkey character varying(5000) DEFAULT nextval('public.employeesections_employeesections_pkey_seq'::regclass)
);


ALTER TABLE public.employeesections OWNER TO postgres;

--
-- Name: fobcodes_fobcodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fobcodes_fobcodes_pkey_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fobcodes_fobcodes_pkey_seq OWNER TO postgres;

--
-- Name: fobcodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fobcodes (
    fobcode character varying(5000),
    desctext character varying(5000),
    fobcodes_pkey integer DEFAULT nextval('public.fobcodes_fobcodes_pkey_seq'::regclass)
);


ALTER TABLE public.fobcodes OWNER TO postgres;

--
-- Name: forecastheader_forecastheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.forecastheader_forecastheader_pkey_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.forecastheader_forecastheader_pkey_seq OWNER TO postgres;

--
-- Name: forecastheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.forecastheader (
    forecastid character varying(5000),
    employeeid character varying(5000),
    originationdate character varying(5000),
    notes character varying(5000),
    mrpinputflag boolean,
    forecastheader_pkey integer DEFAULT nextval('public.forecastheader_forecastheader_pkey_seq'::regclass)
);


ALTER TABLE public.forecastheader OWNER TO postgres;

--
-- Name: forecastparts_forecastparts_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.forecastparts_forecastparts_pkey_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.forecastparts_forecastparts_pkey_seq OWNER TO postgres;

--
-- Name: forecastparts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.forecastparts (
    forecastid character varying(5000),
    partnumber character varying(5000),
    timefence real,
    forecastparts_pkey integer DEFAULT nextval('public.forecastparts_forecastparts_pkey_seq'::regclass)
);


ALTER TABLE public.forecastparts OWNER TO postgres;

--
-- Name: forecastquantities_forecastquantities_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.forecastquantities_forecastquantities_pkey_seq
    START WITH 8
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.forecastquantities_forecastquantities_pkey_seq OWNER TO postgres;

--
-- Name: forecastquantities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.forecastquantities (
    forecastid character varying(5000),
    partnumber character varying(5000),
    quantityid integer,
    forecaststartdate character varying(5000),
    forecastenddate character varying(5000),
    forecastquantity real,
    forecastquantities_pkey integer DEFAULT nextval('public.forecastquantities_forecastquantities_pkey_seq'::regclass)
);


ALTER TABLE public.forecastquantities OWNER TO postgres;

--
-- Name: icncodes_icncodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.icncodes_icncodes_pkey_seq
    START WITH 7
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.icncodes_icncodes_pkey_seq OWNER TO postgres;

--
-- Name: icncodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.icncodes (
    icncode character varying(5000),
    desctext character varying(5000),
    icncodes_pkey integer DEFAULT nextval('public.icncodes_icncodes_pkey_seq'::regclass)
);


ALTER TABLE public.icncodes OWNER TO postgres;

--
-- Name: intrastatrates_intrastatrates_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.intrastatrates_intrastatrates_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.intrastatrates_intrastatrates_pkey_seq OWNER TO postgres;

--
-- Name: intrastatrates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.intrastatrates (
    icncode character varying(5000),
    regioncode character varying(5000),
    taxcode character varying(5000),
    intrastatrates_pkey character varying(5000) DEFAULT nextval('public.intrastatrates_intrastatrates_pkey_seq'::regclass)
);


ALTER TABLE public.intrastatrates OWNER TO postgres;

--
-- Name: intrastatreport_intrastatreport_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.intrastatreport_intrastatreport_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.intrastatreport_intrastatreport_pkey_seq OWNER TO postgres;

--
-- Name: intrastatreport; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.intrastatreport (
    transactionid character varying(5000),
    regioncode character varying(5000),
    icncode character varying(5000),
    linenumber character varying(5000),
    transactiondate character varying(5000),
    taxrate character varying(5000),
    sonumber character varying(5000),
    ponumber character varying(5000),
    cost character varying(5000),
    vatregnumber character varying(5000),
    vatbranchid character varying(5000),
    intrastatreport_pkey character varying(5000) DEFAULT nextval('public.intrastatreport_intrastatreport_pkey_seq'::regclass)
);


ALTER TABLE public.intrastatreport OWNER TO postgres;

--
-- Name: inventorylots_inventorylots_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventorylots_inventorylots_pkey_seq
    START WITH 92
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventorylots_inventorylots_pkey_seq OWNER TO postgres;

--
-- Name: inventorylots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventorylots (
    partnumber character varying(5000),
    departmentcode character varying(5000),
    locationcode character varying(5000),
    snlotnumber character varying(5000),
    jobnumber character varying(5000),
    datereceived character varying(5000),
    quantity real,
    materialcost real,
    inventorylots_pkey integer DEFAULT nextval('public.inventorylots_inventorylots_pkey_seq'::regclass)
);


ALTER TABLE public.inventorylots OWNER TO postgres;

--
-- Name: inventorytags_inventorytags_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventorytags_inventorytags_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventorytags_inventorytags_pkey_seq OWNER TO postgres;

--
-- Name: inventorytags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventorytags (
    tagnumber character varying(5000),
    partnumber character varying(5000),
    departmentcode character varying(5000),
    locationcode character varying(5000),
    snlotnumber character varying(5000),
    jobnumber character varying(5000),
    inventoryquantity character varying(5000),
    countquantity character varying(5000),
    enteredby character varying(5000),
    employeeid character varying(5000),
    closedflag character varying(5000),
    inventorytags_pkey character varying(5000) DEFAULT nextval('public.inventorytags_inventorytags_pkey_seq'::regclass),
    iscounted character varying(5000)
);


ALTER TABLE public.inventorytags OWNER TO postgres;

--
-- Name: invoicedetail_invoicedetail_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoicedetail_invoicedetail_pkey_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoicedetail_invoicedetail_pkey_seq OWNER TO postgres;

--
-- Name: invoicedetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoicedetail (
    invoicenumber real,
    invoiceline integer,
    sonumber character varying(5000),
    soline integer,
    partnumber character varying(5000),
    quantity real,
    price real,
    salesuom character varying(5000),
    taxableflag boolean,
    taxcode2 character varying(5000),
    taxrate2 real,
    taxflag2 boolean,
    taxcode3 character varying(5000),
    taxrate3 real,
    taxflag3 boolean,
    basetaxcode character varying(5000),
    basetaxrate real,
    invoicedetail_pkey integer DEFAULT nextval('public.invoicedetail_invoicedetail_pkey_seq'::regclass)
);


ALTER TABLE public.invoicedetail OWNER TO postgres;

--
-- Name: invoiceheader_invoiceheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoiceheader_invoiceheader_pkey_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoiceheader_invoiceheader_pkey_seq OWNER TO postgres;

--
-- Name: invoiceheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoiceheader (
    invoicenumber real,
    customerid character varying(5000),
    sonumber character varying(5000),
    enteredby character varying(5000),
    shipmentdate character varying(5000),
    freightamount real,
    trackingnumber character varying(5000),
    numberofpieces real,
    weight character varying(5000),
    carrier character varying(5000),
    billoflading character varying(5000),
    notes character varying(5000),
    userdefined1 character varying(5000),
    userdefined2 character varying(5000),
    invoiceheader_pkey integer DEFAULT nextval('public.invoiceheader_invoiceheader_pkey_seq'::regclass)
);


ALTER TABLE public.invoiceheader OWNER TO postgres;

--
-- Name: isc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.isc (
    isc character varying(5000),
    desctext character varying(5000)
);


ALTER TABLE public.isc OWNER TO postgres;

--
-- Name: jobmaster_jobmaster_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.jobmaster_jobmaster_pkey_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.jobmaster_jobmaster_pkey_seq OWNER TO postgres;

--
-- Name: jobmaster; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jobmaster (
    jobnumber character varying(5000),
    desctext character varying(5000),
    closedflag boolean,
    userdefined1 character varying(5000),
    userdefined2 character varying(5000),
    jobmaster_pkey integer DEFAULT nextval('public.jobmaster_jobmaster_pkey_seq'::regclass)
);


ALTER TABLE public.jobmaster OWNER TO postgres;

--
-- Name: labordistribution_labordistribution_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.labordistribution_labordistribution_pkey_seq
    START WITH 7
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.labordistribution_labordistribution_pkey_seq OWNER TO postgres;

--
-- Name: labordistribution; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.labordistribution (
    wonumber character varying(5000),
    laborid integer,
    partnumber character varying(5000),
    sequenceid integer,
    employeeid character varying(5000),
    startdate character varying(5000),
    stopdate character varying(5000),
    quantitycompleted real,
    accountnumber integer,
    wagerate real,
    quantityscrapped real,
    scrapaccount character varying(5000),
    labordistribution_pkey integer DEFAULT nextval('public.labordistribution_labordistribution_pkey_seq'::regclass)
);


ALTER TABLE public.labordistribution OWNER TO postgres;

--
-- Name: licenseinfo_licenseinfo_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.licenseinfo_licenseinfo_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.licenseinfo_licenseinfo_pkey_seq OWNER TO postgres;

--
-- Name: licenseinfo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.licenseinfo (
    controlname character varying(5000),
    license character varying(5000),
    licenseinfo_pkey character varying(5000) DEFAULT nextval('public.licenseinfo_licenseinfo_pkey_seq'::regclass)
);


ALTER TABLE public.licenseinfo OWNER TO postgres;

--
-- Name: mrpjobs_mrpjobs_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mrpjobs_mrpjobs_pkey_seq
    START WITH 948
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mrpjobs_mrpjobs_pkey_seq OWNER TO postgres;

--
-- Name: mrpjobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mrpjobs (
    mrpheaderid integer,
    mrpjobid integer,
    priority integer,
    jobnumber character varying(5000),
    partnumber character varying(5000),
    mrpjobs_pkey integer DEFAULT nextval('public.mrpjobs_mrpjobs_pkey_seq'::regclass),
    onhand real
);


ALTER TABLE public.mrpjobs OWNER TO postgres;

--
-- Name: mrpparts_mrpparts_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mrpparts_mrpparts_pkey_seq
    START WITH 1044
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mrpparts_mrpparts_pkey_seq OWNER TO postgres;

--
-- Name: mrpparts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mrpparts (
    mrpheaderid integer,
    priority integer,
    partnumber character varying(5000),
    isc character varying(5000),
    omc character varying(5000),
    safetystock real,
    yieldfactor real,
    orderquantity real,
    leadtime real,
    ordermultiple real,
    planner character varying(5000),
    mrpparts_pkey integer DEFAULT nextval('public.mrpparts_mrpparts_pkey_seq'::regclass)
);


ALTER TABLE public.mrpparts OWNER TO postgres;

--
-- Name: mrpplanning; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mrpplanning (
    mrpheaderid integer,
    mrpjobid integer,
    partnumber character varying(5000),
    jobnumber character varying(5000),
    posttype integer,
    priority integer,
    startdate character varying(5000),
    forecastenddate character varying(5000),
    requireddate character varying(5000),
    reference character varying(5000),
    referenceline integer,
    startquantity real,
    requiredquantity real,
    balance real,
    action integer,
    pegging character varying(5000),
    movedate character varying(5000),
    balancesortorder integer,
    mrpplanningid integer
);


ALTER TABLE public.mrpplanning OWNER TO postgres;

--
-- Name: omc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.omc (
    omc character varying(5000),
    desctext character varying(5000)
);


ALTER TABLE public.omc OWNER TO postgres;

--
-- Name: operationcodes_operationcodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.operationcodes_operationcodes_pkey_seq
    START WITH 39
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.operationcodes_operationcodes_pkey_seq OWNER TO postgres;

--
-- Name: operationcodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.operationcodes (
    operationcode character varying(5000),
    desctext character varying(5000),
    operationcodes_pkey integer DEFAULT nextval('public.operationcodes_operationcodes_pkey_seq'::regclass)
);


ALTER TABLE public.operationcodes OWNER TO postgres;

--
-- Name: partdocuments_partdocuments_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partdocuments_partdocuments_pkey_seq
    START WITH 67
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.partdocuments_partdocuments_pkey_seq OWNER TO postgres;

--
-- Name: partdocuments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partdocuments (
    partnumber character varying(5000),
    documentid character varying(5000),
    documentlocation character varying(5000),
    documentrevision character varying(5000),
    documentsize character varying(5000),
    desctext character varying(5000),
    ecnnumber character varying(5000),
    effectivedate character varying(5000),
    obsoletedate character varying(5000),
    jobnumber character varying(5000),
    notes character varying(5000),
    partdocuments_pkey integer DEFAULT nextval('public.partdocuments_partdocuments_pkey_seq'::regclass),
    documentpath character varying(5000)
);


ALTER TABLE public.partdocuments OWNER TO postgres;

--
-- Name: partmaster_partmaster_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partmaster_partmaster_pkey_seq
    START WITH 57
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.partmaster_partmaster_pkey_seq OWNER TO postgres;

--
-- Name: partmaster; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partmaster (
    partnumber character varying(5000) CONSTRAINT partmaster_partnumber_notnull NOT NULL,
    revision character varying(5000),
    desctext character varying(5000),
    stockuom character varying(5000),
    densitycode character varying(5000),
    bomlevel character varying(5000),
    graphicpath character varying(5000),
    dimension character varying(5000),
    weight character varying(5000),
    userdefined1 character varying(5000),
    enteredby character varying(5000),
    dateadded character varying(5000),
    engnotes character varying(5000),
    isc character varying(5000),
    omc character varying(5000),
    departmentcode character varying(5000),
    stockroomcode character varying(5000),
    locationcode integer,
    uompurchase character varying(5000),
    leadtime real,
    ordermultiple real,
    yieldfactor real,
    safetystock real,
    orderquantity real,
    defaultpocost real,
    listprice real,
    suocode character varying(5000),
    commoditycode character varying(5000),
    icncode character varying(5000),
    productclass character varying(5000),
    productpricecode character varying(5000),
    specialstorage boolean,
    shelflife real,
    standardhours real,
    partcommflag boolean,
    partcommrate real,
    taxableflag boolean,
    taxcode character varying(5000),
    userdefined2 character varying(5000),
    lastxactiondate character varying(5000),
    ytdusage real,
    abccode character varying(5000),
    abcdollarusage real,
    abcpartpercent character varying(5000),
    abcdollarpercent character varying(5000),
    lastcountdate character varying(5000),
    generatetagflag boolean,
    stdmaterialcost real,
    stdburdencost real,
    stdlaborcost real,
    stdsetupcost real,
    stdsubcontcost real,
    costrevisiondate character varying(5000),
    materialcost real,
    laborcost real,
    burdencost real,
    setupcost real,
    subcontcost real,
    cost real,
    partmaster_pkey integer DEFAULT nextval('public.partmaster_partmaster_pkey_seq'::regclass)
);


ALTER TABLE public.partmaster OWNER TO postgres;

--
-- Name: partxreference_partxreference_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partxreference_partxreference_pkey_seq
    START WITH 70
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.partxreference_partxreference_pkey_seq OWNER TO postgres;

--
-- Name: partxreference; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partxreference (
    partnumber character varying(5000),
    partxreference character varying(5000),
    supplierid character varying(5000),
    xrefdesctext character varying(5000),
    supplierrating real,
    supplierleadtime real,
    approvedsource boolean,
    supplierprice real,
    userdefined1 character varying(5000),
    userdefined2 character varying(5000),
    partxreference_pkey integer DEFAULT nextval('public.partxreference_partxreference_pkey_seq'::regclass)
);


ALTER TABLE public.partxreference OWNER TO postgres;

--
-- Name: pipissues_pipissues_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pipissues_pipissues_pkey_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pipissues_pipissues_pkey_seq OWNER TO postgres;

--
-- Name: pipissues; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pipissues (
    ponumber character varying(5000),
    poline integer,
    issueid integer,
    partnumber character varying(5000),
    departmentcode character varying(5000),
    locationcode integer,
    snlotnumber character varying(5000),
    jobnumber character varying(5000),
    quantityrequired character varying(5000),
    materialcost real,
    uomcode character varying(5000),
    pipissues_pkey integer DEFAULT nextval('public.pipissues_pipissues_pkey_seq'::regclass),
    quantityreleased real,
    quantityscrapped real
);


ALTER TABLE public.pipissues OWNER TO postgres;

--
-- Name: podetail_podetail_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.podetail_podetail_pkey_seq
    START WITH 22
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.podetail_podetail_pkey_seq OWNER TO postgres;

--
-- Name: podetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.podetail (
    ponumber character varying(5000),
    poline integer,
    taxableflag boolean,
    partnumber character varying(5000),
    revision character varying(5000),
    partxreference character varying(5000),
    purchaseuom character varying(5000),
    pounitprice real,
    quantityordered real,
    kitpartflag boolean,
    requireddate character varying(5000),
    quantityreceived real,
    lastreceiptdate character varying(5000),
    quantityrtv real,
    quantityreleased real,
    releasedate character varying(5000),
    linenotes character varying(5000),
    jobnumber character varying(5000),
    taxflag2 boolean,
    taxflag3 boolean,
    basetaxcode character varying(5000),
    taxcode2 character varying(5000),
    taxcode3 character varying(5000),
    departmentcode character varying(5000),
    userdefined1 character varying(5000),
    userdefined2 character varying(5000),
    closedflag boolean,
    podetail_pkey integer DEFAULT nextval('public.podetail_podetail_pkey_seq'::regclass),
    startdate character varying(5000)
);


ALTER TABLE public.podetail OWNER TO postgres;

--
-- Name: poheader_poheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.poheader_poheader_pkey_seq
    START WITH 12
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.poheader_poheader_pkey_seq OWNER TO postgres;

--
-- Name: poheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.poheader (
    ponumber character varying(5000),
    orderdate character varying(5000),
    supplierid character varying(5000),
    requestedby character varying(5000),
    requisitionnumber character varying(5000),
    departmentcode character varying(5000),
    termscode character varying(5000),
    shipviacode character varying(5000),
    fobcode character varying(5000),
    requireddate character varying(5000),
    enteredby character varying(5000),
    buyercode character varying(5000),
    notes character varying(5000),
    closedflag boolean,
    billtoaddress integer,
    shiptoaddress integer,
    supplieraddress integer,
    currencycode character varying(5000),
    exchangerate real,
    regioncode character varying(5000),
    apholdflag boolean,
    poplacedwith character varying(5000),
    ordertype character varying(5000),
    userdefined character varying(5000),
    poheader_pkey integer DEFAULT nextval('public.poheader_poheader_pkey_seq'::regclass),
    suppliercontact character varying(5000)
);


ALTER TABLE public.poheader OWNER TO postgres;

--
-- Name: poshortages_poshortages_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.poshortages_poshortages_pkey_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.poshortages_poshortages_pkey_seq OWNER TO postgres;

--
-- Name: poshortages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.poshortages (
    ponumber character varying(5000),
    linenumber integer,
    partnumber character varying(5000),
    uomcode character varying(5000),
    transactiondate character varying(5000),
    quantity real,
    poshortages_pkey integer DEFAULT nextval('public.poshortages_poshortages_pkey_seq'::regclass)
);


ALTER TABLE public.poshortages OWNER TO postgres;

--
-- Name: preferences_preferences_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.preferences_preferences_pkey_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.preferences_preferences_pkey_seq OWNER TO postgres;

--
-- Name: preferences; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.preferences (
    dbstructureversion real,
    datadefinitionsversion real,
    autogenerateso boolean,
    autogeneratepo boolean,
    autogeneratewo boolean,
    autogenerateiv boolean,
    soformat character varying(5000),
    poformat character varying(5000),
    woformat character varying(5000),
    ivformat character varying(5000),
    quantitydecimals real,
    costtype real,
    costdecimals real,
    basecurrency character varying(5000),
    monday boolean,
    tuesday boolean,
    wednesday boolean,
    thursday boolean,
    friday boolean,
    saturday boolean,
    sunday boolean,
    dailystarttime character varying(5000),
    dailystoptime character varying(5000),
    uselabordistribution boolean,
    pobilltoaddress integer,
    poshiptoaddress integer,
    defaultpotaxcode character varying(5000),
    defaultapdept character varying(5000),
    defaultcogsdept character varying(5000),
    dateformat character varying(5000),
    dateepoch real,
    uomblength character varying(5000),
    uombunit character varying(5000),
    uombvolume character varying(5000),
    uombweight character varying(5000),
    requireintrastat boolean,
    requireinvoicing boolean,
    invoiceremittoaddress integer,
    usemultitiertax boolean,
    inventoryvariantsdept character varying(5000),
    updatestandardhours boolean,
    updatelaborcost boolean,
    updatesetupcost boolean,
    includezeroonhanda boolean,
    numberaparts integer,
    includezeroonhandb boolean,
    numberbparts integer,
    includezeroonhandc boolean,
    numbercparts integer,
    preferences_pkey integer DEFAULT nextval('public.preferences_preferences_pkey_seq'::regclass),
    uombarea character varying(5000),
    appversion real
);


ALTER TABLE public.preferences OWNER TO postgres;

--
-- Name: pricebreakstructures_pricebreakstructures_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pricebreakstructures_pricebreakstructures_pkey_seq
    START WITH 25
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pricebreakstructures_pricebreakstructures_pkey_seq OWNER TO postgres;

--
-- Name: pricebreakstructures; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pricebreakstructures (
    customerdisclevel character varying(5000),
    productpricecode character varying(50),
    pricebreakquantity real,
    pricebreakdiscount real,
    desctext character varying(50),
    pricebreakstructures_pkey integer DEFAULT nextval('public.pricebreakstructures_pricebreakstructures_pkey_seq'::regclass)
);


ALTER TABLE public.pricebreakstructures OWNER TO postgres;

--
-- Name: pricediscountcodes_pricediscountcodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pricediscountcodes_pricediscountcodes_pkey_seq
    START WITH 13
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pricediscountcodes_pricediscountcodes_pkey_seq OWNER TO postgres;

--
-- Name: pricediscountcodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pricediscountcodes (
    pricecode character varying(50),
    discountpercentage real,
    desctext character varying(50),
    pricediscountcodes_pkey integer DEFAULT nextval('public.pricediscountcodes_pricediscountcodes_pkey_seq'::regclass)
);


ALTER TABLE public.pricediscountcodes OWNER TO postgres;

--
-- Name: productclasscodes_productclasscodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productclasscodes_productclasscodes_pkey_seq
    START WITH 9
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.productclasscodes_productclasscodes_pkey_seq OWNER TO postgres;

--
-- Name: productclasscodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productclasscodes (
    productclass character varying(50),
    revenueaccount integer,
    expenseaccount integer,
    desctext character varying(50),
    productclasscodes_pkey integer DEFAULT nextval('public.productclasscodes_productclasscodes_pkey_seq'::regclass)
);


ALTER TABLE public.productclasscodes OWNER TO postgres;

--
-- Name: productdisccodes_productdisccodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productdisccodes_productdisccodes_pkey_seq
    START WITH 7
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.productdisccodes_productdisccodes_pkey_seq OWNER TO postgres;

--
-- Name: productdisccodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productdisccodes (
    productpricecode character varying(50),
    desctext character varying(50),
    productdisccodes_pkey integer DEFAULT nextval('public.productdisccodes_productdisccodes_pkey_seq'::regclass)
);


ALTER TABLE public.productdisccodes OWNER TO postgres;

--
-- Name: refdesignators_refdesignators_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.refdesignators_refdesignators_pkey_seq
    START WITH 21
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.refdesignators_refdesignators_pkey_seq OWNER TO postgres;

--
-- Name: refdesignators; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.refdesignators (
    assembly character varying(50),
    component character varying(50),
    refdesignator character varying(50),
    desctext character varying(50),
    notes character varying(64),
    refdesignators_pkey integer DEFAULT nextval('public.refdesignators_refdesignators_pkey_seq'::regclass)
);


ALTER TABLE public.refdesignators OWNER TO postgres;

--
-- Name: regioncodes_regioncodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.regioncodes_regioncodes_pkey_seq
    START WITH 19
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.regioncodes_regioncodes_pkey_seq OWNER TO postgres;

--
-- Name: regioncodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.regioncodes (
    regioncode character varying(50),
    desctext character varying(50),
    regioncodes_pkey integer DEFAULT nextval('public.regioncodes_regioncodes_pkey_seq'::regclass)
);


ALTER TABLE public.regioncodes OWNER TO postgres;

--
-- Name: routers_routers_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.routers_routers_pkey_seq
    START WITH 84
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.routers_routers_pkey_seq OWNER TO postgres;

--
-- Name: routers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.routers (
    partnumber character varying(50),
    sequenceid integer,
    operationcode character varying(50),
    isalternate boolean,
    notes character varying(50),
    workcenterid character varying(50),
    queuetime real,
    setuptime real,
    runtime real,
    routers_pkey integer DEFAULT nextval('public.routers_routers_pkey_seq'::regclass)
);


ALTER TABLE public.routers OWNER TO postgres;

--
-- Name: securitysectiondetail_securitysectiondetail_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.securitysectiondetail_securitysectiondetail_pkey_seq
    START WITH 87387
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.securitysectiondetail_securitysectiondetail_pkey_seq OWNER TO postgres;

--
-- Name: securitysectiondetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.securitysectiondetail (
    sectionname character varying(50),
    detailname character varying(50),
    maxlevel integer,
    propertybag character varying(50),
    detailid integer,
    inuse boolean,
    securitysectiondetail_pkey integer DEFAULT nextval('public.securitysectiondetail_securitysectiondetail_pkey_seq'::regclass)
);


ALTER TABLE public.securitysectiondetail OWNER TO postgres;

--
-- Name: securitysections_securitysections_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.securitysections_securitysections_pkey_seq
    START WITH 12416
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.securitysections_securitysections_pkey_seq OWNER TO postgres;

--
-- Name: securitysections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.securitysections (
    sectionname character varying(50),
    maxlevel integer,
    propertybag character varying(50),
    sectionid integer,
    inuse boolean,
    securitysections_pkey integer DEFAULT nextval('public.securitysections_securitysections_pkey_seq'::regclass)
);


ALTER TABLE public.securitysections OWNER TO postgres;

--
-- Name: seriallotnumbers_seriallotnumbers_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.seriallotnumbers_seriallotnumbers_pkey_seq
    START WITH 21
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.seriallotnumbers_seriallotnumbers_pkey_seq OWNER TO postgres;

--
-- Name: seriallotnumbers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.seriallotnumbers (
    sntranid integer,
    partnumber character varying(50),
    snlotnumber character varying(50),
    expirationdate character varying(50),
    transactiondate character varying(50),
    reference character varying(50),
    posttype character varying(50),
    seriallotnumbers_pkey integer DEFAULT nextval('public.seriallotnumbers_seriallotnumbers_pkey_seq'::regclass)
);


ALTER TABLE public.seriallotnumbers OWNER TO postgres;

--
-- Name: shiftdowntime_shiftdowntime_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shiftdowntime_shiftdowntime_pkey_seq
    START WITH 34
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shiftdowntime_shiftdowntime_pkey_seq OWNER TO postgres;

--
-- Name: shiftdowntime; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shiftdowntime (
    workcenterid character varying(50),
    shiftid character varying(50),
    startdate character varying(50),
    reasondown character varying(50),
    shiftdowntime_pkey integer DEFAULT nextval('public.shiftdowntime_shiftdowntime_pkey_seq'::regclass)
);


ALTER TABLE public.shiftdowntime OWNER TO postgres;

--
-- Name: shipviacodes_shipviacodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shipviacodes_shipviacodes_pkey_seq
    START WITH 21
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shipviacodes_shipviacodes_pkey_seq OWNER TO postgres;

--
-- Name: shipviacodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shipviacodes (
    shipviacode character varying(50),
    desctext character varying(50),
    shipviacodes_pkey integer DEFAULT nextval('public.shipviacodes_shipviacodes_pkey_seq'::regclass)
);


ALTER TABLE public.shipviacodes OWNER TO postgres;

--
-- Name: sodetail_sodetail_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sodetail_sodetail_pkey_seq
    START WITH 25
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sodetail_sodetail_pkey_seq OWNER TO postgres;

--
-- Name: sodetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sodetail (
    sonumber character varying(50),
    soline integer,
    customerline character varying(50),
    taxableflag boolean,
    partnumber character varying(50),
    partxreference character varying(50),
    quantityordered real,
    actualshipdate character varying(50),
    quantityshipped real,
    quantityreturned real,
    scheduledshipdate character varying(50),
    customerprice real,
    salesuom character varying(50),
    notes character varying(50),
    taxcode character varying(50),
    taxflag2 boolean,
    taxflag3 boolean,
    taxcode2 character varying(50),
    taxcode3 character varying(50),
    closedflag boolean,
    productclass character varying(50),
    userdefined1 character varying(50),
    userdefined character varying(50),
    sodetail_pkey integer DEFAULT nextval('public.sodetail_sodetail_pkey_seq'::regclass)
);


ALTER TABLE public.sodetail OWNER TO postgres;

--
-- Name: soheader_soheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.soheader_soheader_pkey_seq
    START WITH 14
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.soheader_soheader_pkey_seq OWNER TO postgres;

--
-- Name: soheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.soheader (
    sonumber character varying(5000),
    orderdate character varying(5000),
    customerid character varying(5000),
    salesperson character varying(5000),
    termscode character varying(5000),
    shipviacode character varying(5000),
    fobcode character varying(5000),
    requireddate character varying(5000),
    enteredby character varying(5000),
    notes character varying(5000),
    billtoaddress character varying(5000),
    shiptoaddress character varying(5000),
    orderedby character varying(5000),
    customerpo character varying(5000),
    pricecode character varying(5000),
    shipholdflag boolean,
    closedflag boolean,
    departmentcode character varying(5000),
    currencycode character varying(5000),
    currencyrate real,
    jobnumber character varying(5000),
    regioncode character varying(5000),
    attention character varying(5000),
    quotenumber character varying(5000),
    ordertype character varying(5000),
    userdefined character varying(5000),
    soheader_pkey integer DEFAULT nextval('public.soheader_soheader_pkey_seq'::regclass),
    billtocontact character varying(5000),
    shiptocontact character varying(5000)
);


ALTER TABLE public.soheader OWNER TO postgres;

--
-- Name: stocklocations_stocklocations_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stocklocations_stocklocations_pkey_seq
    START WITH 46
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stocklocations_stocklocations_pkey_seq OWNER TO postgres;

--
-- Name: stocklocations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stocklocations (
    departmentcode character varying(50),
    locationcode character varying(5000),
    desctext character varying(50),
    stocklocations_pkey integer DEFAULT nextval('public.stocklocations_stocklocations_pkey_seq'::regclass)
);


ALTER TABLE public.stocklocations OWNER TO postgres;

--
-- Name: suocodes_suocodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.suocodes_suocodes_pkey_seq
    START WITH 7
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.suocodes_suocodes_pkey_seq OWNER TO postgres;

--
-- Name: suocodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suocodes (
    suocode character varying(5000),
    desctext character varying(5000),
    suocodes_pkey integer DEFAULT nextval('public.suocodes_suocodes_pkey_seq'::regclass)
);


ALTER TABLE public.suocodes OWNER TO postgres;

--
-- Name: supplieraddress_supplieraddress_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.supplieraddress_supplieraddress_pkey_seq
    START WITH 42
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.supplieraddress_supplieraddress_pkey_seq OWNER TO postgres;

--
-- Name: supplieraddress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.supplieraddress (
    supplierid character varying(5000),
    addressid character varying(5000),
    addressline1 character varying(5000),
    addressline2 character varying(5000),
    addressline3 character varying(5000),
    addressline4 character varying(5000),
    city character varying(5000),
    state character varying(5000),
    zipcode integer,
    postal character varying(5000),
    country character varying(5000),
    taxcode character varying(5000),
    supplieraddress_pkey integer DEFAULT nextval('public.supplieraddress_supplieraddress_pkey_seq'::regclass)
);


ALTER TABLE public.supplieraddress OWNER TO postgres;

--
-- Name: suppliercontacts_suppliercontacts_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.suppliercontacts_suppliercontacts_pkey_seq
    START WITH 91
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.suppliercontacts_suppliercontacts_pkey_seq OWNER TO postgres;

--
-- Name: suppliercontacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suppliercontacts (
    supplierid character varying(5000),
    contactid character varying(5000),
    addressid character varying(5000),
    name character varying(5000),
    email character varying(5000),
    notes character varying(5000),
    suppliercontacts_pkey integer DEFAULT nextval('public.suppliercontacts_suppliercontacts_pkey_seq'::regclass),
    phone character varying(5000),
    phonefmt character varying(5000),
    fax character varying(5000),
    faxfmt character varying(5000)
);


ALTER TABLE public.suppliercontacts OWNER TO postgres;

--
-- Name: suppliers_suppliers_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.suppliers_suppliers_pkey_seq
    START WITH 22
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.suppliers_suppliers_pkey_seq OWNER TO postgres;

--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suppliers (
    supplierid character varying(50),
    suppliername character varying(50),
    companyaccount character varying(50),
    currencycode character varying(50),
    fobcode character varying(50),
    shipviacode character varying(50),
    termscode character varying(50),
    regioncode character varying(50),
    vatregnumber character varying(50),
    dateadded character varying(50),
    activeflag boolean,
    notes character varying(50),
    apholdflag boolean,
    vatbranchid character varying(50),
    userdefined character varying(50),
    suppliers_pkey integer DEFAULT nextval('public.suppliers_suppliers_pkey_seq'::regclass)
);


ALTER TABLE public.suppliers OWNER TO postgres;

--
-- Name: syskeys_syskeys_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.syskeys_syskeys_pkey_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.syskeys_syskeys_pkey_seq OWNER TO postgres;

--
-- Name: syskeys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.syskeys (
    syskeyname character varying(50),
    syskeymin real,
    lastformat character varying(50),
    syskeys_pkey integer DEFAULT nextval('public.syskeys_syskeys_pkey_seq'::regclass)
);


ALTER TABLE public.syskeys OWNER TO postgres;

--
-- Name: taxcodes_taxcodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.taxcodes_taxcodes_pkey_seq
    START WITH 7
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.taxcodes_taxcodes_pkey_seq OWNER TO postgres;

--
-- Name: taxcodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.taxcodes (
    taxcode character varying(50),
    taxrate real,
    desctext character varying(50),
    liabilityaccount real,
    taxcodes_pkey integer DEFAULT nextval('public.taxcodes_taxcodes_pkey_seq'::regclass)
);


ALTER TABLE public.taxcodes OWNER TO postgres;

--
-- Name: termscodes_termscodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.termscodes_termscodes_pkey_seq
    START WITH 11
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.termscodes_termscodes_pkey_seq OWNER TO postgres;

--
-- Name: termscodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.termscodes (
    termscode character varying(50),
    desctext character varying(50),
    termscodes_pkey integer DEFAULT nextval('public.termscodes_termscodes_pkey_seq'::regclass)
);


ALTER TABLE public.termscodes OWNER TO postgres;

--
-- Name: transactiondetail_transactiondetail_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.transactiondetail_transactiondetail_pkey_seq
    START WITH 35
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transactiondetail_transactiondetail_pkey_seq OWNER TO postgres;

--
-- Name: transactiondetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transactiondetail (
    transactiongroup real,
    transactionid real,
    partnumber character varying(50),
    quantity real,
    fromdepartment character varying(50),
    todepartment character varying(50),
    fromlocation integer,
    tolocation integer,
    snlotnumber character varying(50),
    cost real,
    linenumber integer,
    uomconversion real,
    socost real,
    pocost real,
    wocost real,
    invoiceline integer,
    transactiondetail_pkey integer DEFAULT nextval('public.transactiondetail_transactiondetail_pkey_seq'::regclass),
    transactioninformation character varying(50),
    fromjobnumber character varying(50),
    tojobnumber character varying(50)
);


ALTER TABLE public.transactiondetail OWNER TO postgres;

--
-- Name: transactionheader_transactionheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.transactionheader_transactionheader_pkey_seq
    START WITH 25
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transactionheader_transactionheader_pkey_seq OWNER TO postgres;

--
-- Name: transactionheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transactionheader (
    transactiongroup real,
    transactiontype character varying(50),
    transactiondate character varying(50),
    reference character varying(50),
    notes character varying(50),
    auditdate character varying(50),
    enteredby character varying(50),
    invoicenumber real,
    transactionheader_pkey integer DEFAULT nextval('public.transactionheader_transactionheader_pkey_seq'::regclass)
);


ALTER TABLE public.transactionheader OWNER TO postgres;

--
-- Name: uomcodes_uomcodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.uomcodes_uomcodes_pkey_seq
    START WITH 37
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.uomcodes_uomcodes_pkey_seq OWNER TO postgres;

--
-- Name: uomcodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uomcodes (
    uomcode character varying(50),
    desctext character varying(50),
    uomtype real,
    conversionfactor real,
    uomcodes_pkey integer DEFAULT nextval('public.uomcodes_uomcodes_pkey_seq'::regclass)
);


ALTER TABLE public.uomcodes OWNER TO postgres;

--
-- Name: wipissues_wipissues_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.wipissues_wipissues_pkey_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.wipissues_wipissues_pkey_seq OWNER TO postgres;

--
-- Name: wipissues; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wipissues (
    wonumber character varying(50),
    issueid integer,
    partnumber character varying(50),
    departmentcode character varying(50),
    location integer,
    snlotnumber character varying(50),
    jobnumber character varying(50),
    quantityrequired real,
    quantityreleased real,
    quantityscrapped real,
    materialcost real,
    uomcode character varying(50),
    wipissues_pkey integer DEFAULT nextval('public.wipissues_wipissues_pkey_seq'::regclass)
);


ALTER TABLE public.wipissues OWNER TO postgres;

--
-- Name: woheader_woheader_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.woheader_woheader_pkey_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.woheader_woheader_pkey_seq OWNER TO postgres;

--
-- Name: woheader; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.woheader (
    wonumber character varying(50),
    startdate character varying(50),
    requireddate character varying(50),
    wopriority integer,
    quantitycompleted real,
    quantityreleased real,
    quantityrequired real,
    quantitytostart real,
    partnumber character varying(50),
    workorderuom character varying(50),
    closedflag boolean,
    enteredby character varying(50),
    releaseddate character varying(50),
    jobnumber character varying(50),
    notes character varying(50),
    userdefined character varying(50),
    woheader_pkey integer DEFAULT nextval('public.woheader_woheader_pkey_seq'::regclass)
);


ALTER TABLE public.woheader OWNER TO postgres;

--
-- Name: workcenters_workcenters_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.workcenters_workcenters_pkey_seq
    START WITH 15
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.workcenters_workcenters_pkey_seq OWNER TO postgres;

--
-- Name: workcenters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workcenters (
    workcenterid character varying(50),
    workcentername character varying(50),
    capacity real,
    defaultwagerate real,
    burden character varying(50),
    useshifts boolean,
    wcaccountnumber real,
    workcenters_pkey integer DEFAULT nextval('public.workcenters_workcenters_pkey_seq'::regclass)
);


ALTER TABLE public.workcenters OWNER TO postgres;

--
-- Name: workcentershifts_workcentershifts_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.workcentershifts_workcentershifts_pkey_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.workcentershifts_workcentershifts_pkey_seq OWNER TO postgres;

--
-- Name: workcentershifts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workcentershifts (
    workcenterid character varying(50),
    shiftid character varying(50),
    starttime character varying(50),
    stoptime character varying(50),
    capacity real,
    monday boolean,
    tuesday boolean,
    wednesday boolean,
    thursday boolean,
    friday boolean,
    saturday boolean,
    sunday boolean,
    workcentershifts_pkey integer DEFAULT nextval('public.workcentershifts_workcentershifts_pkey_seq'::regclass)
);


ALTER TABLE public.workcentershifts OWNER TO postgres;

--
-- Name: woshortages_woshortages_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.woshortages_woshortages_pkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.woshortages_woshortages_pkey_seq OWNER TO postgres;

--
-- Name: woshortages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.woshortages (
    wonumber character varying(50),
    partnumber character varying(50),
    uom character varying(50),
    transactiondate character varying(50),
    quantity character varying(50),
    woshortages_pkey character varying(50) DEFAULT nextval('public.woshortages_woshortages_pkey_seq'::regclass)
);


ALTER TABLE public.woshortages OWNER TO postgres;

--
-- Name: zipcodes_zipcodes_pkey_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zipcodes_zipcodes_pkey_seq
    START WITH 86063
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.zipcodes_zipcodes_pkey_seq OWNER TO postgres;

--
-- Name: zipcodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zipcodes (
    zipcode character varying(5000),
    state character varying(5000),
    city character varying(50),
    county character varying(50),
    areacode integer,
    timefromgmt integer,
    dst boolean,
    zipcodes_pkey integer DEFAULT nextval('public.zipcodes_zipcodes_pkey_seq'::regclass)
);


ALTER TABLE public.zipcodes OWNER TO postgres;

--
-- Name: partmaster partmaster_partnumber_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partmaster
    ADD CONSTRAINT partmaster_partnumber_unique UNIQUE (partnumber);


--
-- Name: partmaster partmaster_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partmaster
    ADD CONSTRAINT partmaster_pkey PRIMARY KEY (partnumber);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO eng;
GRANT USAGE ON SCHEMA public TO mkt;
GRANT USAGE ON SCHEMA public TO mfg;
GRANT USAGE ON SCHEMA public TO purch;
GRANT USAGE ON SCHEMA public TO supervisor;


--
-- Name: TABLE audit; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.audit TO eng;
GRANT SELECT ON TABLE public.audit TO mkt;
GRANT SELECT ON TABLE public.audit TO mfg;
GRANT SELECT ON TABLE public.audit TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.audit TO supervisor;


--
-- Name: TABLE bom; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.bom TO eng;
GRANT SELECT ON TABLE public.bom TO mkt;
GRANT SELECT ON TABLE public.bom TO mfg;
GRANT SELECT ON TABLE public.bom TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.bom TO supervisor;


--
-- Name: TABLE calendar; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.calendar TO eng;
GRANT SELECT ON TABLE public.calendar TO mkt;
GRANT SELECT ON TABLE public.calendar TO mfg;
GRANT SELECT ON TABLE public.calendar TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.calendar TO supervisor;


--
-- Name: TABLE commoditycodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.commoditycodes TO eng;
GRANT SELECT ON TABLE public.commoditycodes TO mfg;
GRANT SELECT ON TABLE public.commoditycodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.commoditycodes TO supervisor;
GRANT SELECT,UPDATE ON TABLE public.commoditycodes TO mkt;


--
-- Name: TABLE company; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.company TO eng;
GRANT SELECT ON TABLE public.company TO mkt;
GRANT SELECT ON TABLE public.company TO mfg;
GRANT SELECT ON TABLE public.company TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.company TO supervisor;


--
-- Name: TABLE companyaddress; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.companyaddress TO eng;
GRANT SELECT ON TABLE public.companyaddress TO mkt;
GRANT SELECT ON TABLE public.companyaddress TO mfg;
GRANT SELECT ON TABLE public.companyaddress TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.companyaddress TO supervisor;


--
-- Name: TABLE creditmemodetail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.creditmemodetail TO eng;
GRANT SELECT ON TABLE public.creditmemodetail TO mkt;
GRANT SELECT ON TABLE public.creditmemodetail TO mfg;
GRANT SELECT ON TABLE public.creditmemodetail TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.creditmemodetail TO supervisor;


--
-- Name: TABLE creditmemoheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.creditmemoheader TO eng;
GRANT SELECT ON TABLE public.creditmemoheader TO mkt;
GRANT SELECT ON TABLE public.creditmemoheader TO mfg;
GRANT SELECT ON TABLE public.creditmemoheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.creditmemoheader TO supervisor;


--
-- Name: TABLE crpdetail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.crpdetail TO eng;
GRANT SELECT ON TABLE public.crpdetail TO mkt;
GRANT SELECT ON TABLE public.crpdetail TO mfg;
GRANT SELECT ON TABLE public.crpdetail TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.crpdetail TO supervisor;


--
-- Name: TABLE crpheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.crpheader TO eng;
GRANT SELECT ON TABLE public.crpheader TO mkt;
GRANT SELECT ON TABLE public.crpheader TO mfg;
GRANT SELECT ON TABLE public.crpheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.crpheader TO supervisor;


--
-- Name: TABLE crpsummary; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.crpsummary TO eng;
GRANT SELECT ON TABLE public.crpsummary TO mkt;
GRANT SELECT ON TABLE public.crpsummary TO mfg;
GRANT SELECT ON TABLE public.crpsummary TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.crpsummary TO supervisor;


--
-- Name: TABLE currencycodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.currencycodes TO eng;
GRANT SELECT ON TABLE public.currencycodes TO mfg;
GRANT SELECT ON TABLE public.currencycodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.currencycodes TO supervisor;
GRANT SELECT,UPDATE ON TABLE public.currencycodes TO mkt;


--
-- Name: TABLE customeraddress; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.customeraddress TO eng;
GRANT SELECT ON TABLE public.customeraddress TO mkt;
GRANT SELECT ON TABLE public.customeraddress TO mfg;
GRANT SELECT ON TABLE public.customeraddress TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.customeraddress TO supervisor;


--
-- Name: TABLE customercontacts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.customercontacts TO eng;
GRANT SELECT ON TABLE public.customercontacts TO mkt;
GRANT SELECT ON TABLE public.customercontacts TO mfg;
GRANT SELECT ON TABLE public.customercontacts TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.customercontacts TO supervisor;


--
-- Name: TABLE customerdisclevel; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.customerdisclevel TO eng;
GRANT SELECT ON TABLE public.customerdisclevel TO mkt;
GRANT SELECT ON TABLE public.customerdisclevel TO mfg;
GRANT SELECT ON TABLE public.customerdisclevel TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.customerdisclevel TO supervisor;


--
-- Name: TABLE customers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.customers TO eng;
GRANT SELECT ON TABLE public.customers TO mkt;
GRANT SELECT ON TABLE public.customers TO mfg;
GRANT SELECT ON TABLE public.customers TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.customers TO supervisor;


--
-- Name: TABLE datadefinitions; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.datadefinitions TO eng;
GRANT SELECT ON TABLE public.datadefinitions TO mkt;
GRANT SELECT ON TABLE public.datadefinitions TO mfg;
GRANT SELECT ON TABLE public.datadefinitions TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.datadefinitions TO supervisor;


--
-- Name: TABLE datautilitybatches; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.datautilitybatches TO eng;
GRANT SELECT ON TABLE public.datautilitybatches TO mkt;
GRANT SELECT ON TABLE public.datautilitybatches TO mfg;
GRANT SELECT ON TABLE public.datautilitybatches TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.datautilitybatches TO supervisor;


--
-- Name: TABLE densitycodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.densitycodes TO eng;
GRANT SELECT ON TABLE public.densitycodes TO mkt;
GRANT SELECT ON TABLE public.densitycodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.densitycodes TO supervisor;
GRANT SELECT,INSERT,UPDATE ON TABLE public.densitycodes TO mfg;


--
-- Name: TABLE departmentcodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.departmentcodes TO eng;
GRANT SELECT ON TABLE public.departmentcodes TO mkt;
GRANT SELECT ON TABLE public.departmentcodes TO mfg;
GRANT SELECT ON TABLE public.departmentcodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.departmentcodes TO supervisor;


--
-- Name: TABLE ecnclasscodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.ecnclasscodes TO eng;
GRANT SELECT ON TABLE public.ecnclasscodes TO mfg;
GRANT SELECT ON TABLE public.ecnclasscodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.ecnclasscodes TO supervisor;
GRANT SELECT,UPDATE ON TABLE public.ecnclasscodes TO mkt;


--
-- Name: TABLE ecnheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.ecnheader TO eng;
GRANT SELECT ON TABLE public.ecnheader TO mkt;
GRANT SELECT ON TABLE public.ecnheader TO mfg;
GRANT SELECT ON TABLE public.ecnheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.ecnheader TO supervisor;


--
-- Name: TABLE ecnparts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.ecnparts TO eng;
GRANT SELECT ON TABLE public.ecnparts TO mkt;
GRANT SELECT ON TABLE public.ecnparts TO mfg;
GRANT SELECT ON TABLE public.ecnparts TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.ecnparts TO supervisor;


--
-- Name: TABLE employees; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.employees TO eng;
GRANT SELECT ON TABLE public.employees TO mkt;
GRANT SELECT ON TABLE public.employees TO mfg;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.employees TO supervisor;
GRANT SELECT ON TABLE public.employees TO purch;


--
-- Name: TABLE employeesectiondetail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.employeesectiondetail TO eng;
GRANT SELECT ON TABLE public.employeesectiondetail TO mkt;
GRANT SELECT ON TABLE public.employeesectiondetail TO mfg;
GRANT SELECT ON TABLE public.employeesectiondetail TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.employeesectiondetail TO supervisor;


--
-- Name: TABLE employeesections; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.employeesections TO eng;
GRANT SELECT ON TABLE public.employeesections TO mkt;
GRANT SELECT ON TABLE public.employeesections TO mfg;
GRANT SELECT ON TABLE public.employeesections TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.employeesections TO supervisor;


--
-- Name: TABLE fobcodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.fobcodes TO eng;
GRANT SELECT ON TABLE public.fobcodes TO mkt;
GRANT SELECT ON TABLE public.fobcodes TO mfg;
GRANT SELECT ON TABLE public.fobcodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.fobcodes TO supervisor;


--
-- Name: TABLE forecastheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.forecastheader TO eng;
GRANT SELECT ON TABLE public.forecastheader TO mkt;
GRANT SELECT ON TABLE public.forecastheader TO mfg;
GRANT SELECT ON TABLE public.forecastheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.forecastheader TO supervisor;


--
-- Name: TABLE forecastparts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.forecastparts TO eng;
GRANT SELECT ON TABLE public.forecastparts TO mkt;
GRANT SELECT ON TABLE public.forecastparts TO mfg;
GRANT SELECT ON TABLE public.forecastparts TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.forecastparts TO supervisor;


--
-- Name: TABLE forecastquantities; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.forecastquantities TO eng;
GRANT SELECT ON TABLE public.forecastquantities TO mkt;
GRANT SELECT ON TABLE public.forecastquantities TO mfg;
GRANT SELECT ON TABLE public.forecastquantities TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.forecastquantities TO supervisor;


--
-- Name: TABLE icncodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.icncodes TO eng;
GRANT SELECT ON TABLE public.icncodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.icncodes TO supervisor;
GRANT SELECT,UPDATE ON TABLE public.icncodes TO mkt;
GRANT SELECT,INSERT,UPDATE ON TABLE public.icncodes TO mfg;


--
-- Name: TABLE intrastatrates; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.intrastatrates TO eng;
GRANT SELECT ON TABLE public.intrastatrates TO mkt;
GRANT SELECT ON TABLE public.intrastatrates TO mfg;
GRANT SELECT ON TABLE public.intrastatrates TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.intrastatrates TO supervisor;


--
-- Name: TABLE intrastatreport; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.intrastatreport TO eng;
GRANT SELECT ON TABLE public.intrastatreport TO mkt;
GRANT SELECT ON TABLE public.intrastatreport TO mfg;
GRANT SELECT ON TABLE public.intrastatreport TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.intrastatreport TO supervisor;


--
-- Name: TABLE inventorylots; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.inventorylots TO eng;
GRANT SELECT ON TABLE public.inventorylots TO mkt;
GRANT SELECT ON TABLE public.inventorylots TO mfg;
GRANT SELECT ON TABLE public.inventorylots TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.inventorylots TO supervisor;


--
-- Name: TABLE inventorytags; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.inventorytags TO eng;
GRANT SELECT ON TABLE public.inventorytags TO mkt;
GRANT SELECT ON TABLE public.inventorytags TO mfg;
GRANT SELECT ON TABLE public.inventorytags TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.inventorytags TO supervisor;


--
-- Name: TABLE invoicedetail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.invoicedetail TO eng;
GRANT SELECT ON TABLE public.invoicedetail TO mkt;
GRANT SELECT ON TABLE public.invoicedetail TO mfg;
GRANT SELECT ON TABLE public.invoicedetail TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoicedetail TO supervisor;


--
-- Name: TABLE invoiceheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.invoiceheader TO eng;
GRANT SELECT ON TABLE public.invoiceheader TO mkt;
GRANT SELECT ON TABLE public.invoiceheader TO mfg;
GRANT SELECT ON TABLE public.invoiceheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.invoiceheader TO supervisor;


--
-- Name: TABLE isc; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.isc TO eng;
GRANT SELECT ON TABLE public.isc TO mkt;
GRANT SELECT ON TABLE public.isc TO mfg;
GRANT SELECT ON TABLE public.isc TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.isc TO supervisor;


--
-- Name: TABLE jobmaster; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.jobmaster TO eng;
GRANT SELECT ON TABLE public.jobmaster TO mkt;
GRANT SELECT ON TABLE public.jobmaster TO mfg;
GRANT SELECT ON TABLE public.jobmaster TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.jobmaster TO supervisor;


--
-- Name: TABLE labordistribution; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.labordistribution TO eng;
GRANT SELECT ON TABLE public.labordistribution TO mfg;
GRANT SELECT ON TABLE public.labordistribution TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.labordistribution TO supervisor;
GRANT SELECT,UPDATE ON TABLE public.labordistribution TO mkt;


--
-- Name: TABLE licenseinfo; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.licenseinfo TO eng;
GRANT SELECT ON TABLE public.licenseinfo TO mkt;
GRANT SELECT ON TABLE public.licenseinfo TO mfg;
GRANT SELECT ON TABLE public.licenseinfo TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.licenseinfo TO supervisor;


--
-- Name: TABLE mrpjobs; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.mrpjobs TO eng;
GRANT SELECT ON TABLE public.mrpjobs TO mkt;
GRANT SELECT ON TABLE public.mrpjobs TO mfg;
GRANT SELECT ON TABLE public.mrpjobs TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.mrpjobs TO supervisor;


--
-- Name: TABLE mrpparts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.mrpparts TO mkt;
GRANT SELECT ON TABLE public.mrpparts TO mfg;
GRANT SELECT ON TABLE public.mrpparts TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.mrpparts TO supervisor;
GRANT SELECT,UPDATE ON TABLE public.mrpparts TO eng;


--
-- Name: TABLE mrpplanning; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.mrpplanning TO eng;
GRANT SELECT ON TABLE public.mrpplanning TO mkt;
GRANT SELECT ON TABLE public.mrpplanning TO mfg;
GRANT SELECT ON TABLE public.mrpplanning TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.mrpplanning TO supervisor;


--
-- Name: TABLE omc; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.omc TO eng;
GRANT SELECT ON TABLE public.omc TO mkt;
GRANT SELECT ON TABLE public.omc TO mfg;
GRANT SELECT ON TABLE public.omc TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.omc TO supervisor;


--
-- Name: TABLE operationcodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.operationcodes TO eng;
GRANT SELECT ON TABLE public.operationcodes TO mkt;
GRANT SELECT ON TABLE public.operationcodes TO mfg;
GRANT SELECT ON TABLE public.operationcodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.operationcodes TO supervisor;


--
-- Name: TABLE partdocuments; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.partdocuments TO eng;
GRANT SELECT ON TABLE public.partdocuments TO mkt;
GRANT SELECT ON TABLE public.partdocuments TO mfg;
GRANT SELECT ON TABLE public.partdocuments TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.partdocuments TO supervisor;


--
-- Name: TABLE partmaster; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.partmaster TO eng;
GRANT SELECT ON TABLE public.partmaster TO mkt;
GRANT SELECT ON TABLE public.partmaster TO mfg;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.partmaster TO supervisor;
GRANT SELECT,INSERT,UPDATE ON TABLE public.partmaster TO "20-HCC";
GRANT SELECT ON TABLE public.partmaster TO purch;


--
-- Name: TABLE partxreference; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.partxreference TO eng;
GRANT SELECT ON TABLE public.partxreference TO mkt;
GRANT SELECT ON TABLE public.partxreference TO mfg;
GRANT SELECT ON TABLE public.partxreference TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.partxreference TO supervisor;


--
-- Name: TABLE pipissues; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.pipissues TO eng;
GRANT SELECT ON TABLE public.pipissues TO mkt;
GRANT SELECT ON TABLE public.pipissues TO mfg;
GRANT SELECT ON TABLE public.pipissues TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.pipissues TO supervisor;


--
-- Name: TABLE podetail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.podetail TO eng;
GRANT SELECT ON TABLE public.podetail TO mkt;
GRANT SELECT ON TABLE public.podetail TO mfg;
GRANT SELECT ON TABLE public.podetail TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.podetail TO supervisor;


--
-- Name: TABLE poheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.poheader TO eng;
GRANT SELECT ON TABLE public.poheader TO mkt;
GRANT SELECT ON TABLE public.poheader TO mfg;
GRANT SELECT ON TABLE public.poheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.poheader TO supervisor;


--
-- Name: TABLE poshortages; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.poshortages TO eng;
GRANT SELECT ON TABLE public.poshortages TO mkt;
GRANT SELECT ON TABLE public.poshortages TO mfg;
GRANT SELECT ON TABLE public.poshortages TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.poshortages TO supervisor;


--
-- Name: TABLE preferences; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.preferences TO eng;
GRANT SELECT ON TABLE public.preferences TO mkt;
GRANT SELECT ON TABLE public.preferences TO mfg;
GRANT SELECT ON TABLE public.preferences TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.preferences TO supervisor;


--
-- Name: TABLE pricebreakstructures; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.pricebreakstructures TO eng;
GRANT SELECT ON TABLE public.pricebreakstructures TO mkt;
GRANT SELECT ON TABLE public.pricebreakstructures TO mfg;
GRANT SELECT ON TABLE public.pricebreakstructures TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.pricebreakstructures TO supervisor;


--
-- Name: TABLE pricediscountcodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.pricediscountcodes TO eng;
GRANT SELECT ON TABLE public.pricediscountcodes TO mfg;
GRANT SELECT ON TABLE public.pricediscountcodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.pricediscountcodes TO supervisor;
GRANT SELECT,INSERT ON TABLE public.pricediscountcodes TO mkt;


--
-- Name: TABLE productclasscodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.productclasscodes TO eng;
GRANT SELECT ON TABLE public.productclasscodes TO mkt;
GRANT SELECT ON TABLE public.productclasscodes TO mfg;
GRANT SELECT ON TABLE public.productclasscodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.productclasscodes TO supervisor;


--
-- Name: TABLE productdisccodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.productdisccodes TO eng;
GRANT SELECT ON TABLE public.productdisccodes TO mkt;
GRANT SELECT ON TABLE public.productdisccodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.productdisccodes TO supervisor;
GRANT SELECT,INSERT,UPDATE ON TABLE public.productdisccodes TO mfg;
GRANT SELECT ON TABLE public.productdisccodes TO "40-NAW";


--
-- Name: TABLE refdesignators; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.refdesignators TO eng;
GRANT SELECT ON TABLE public.refdesignators TO mkt;
GRANT SELECT ON TABLE public.refdesignators TO mfg;
GRANT SELECT ON TABLE public.refdesignators TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.refdesignators TO supervisor;


--
-- Name: TABLE regioncodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.regioncodes TO eng;
GRANT SELECT ON TABLE public.regioncodes TO mfg;
GRANT SELECT ON TABLE public.regioncodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.regioncodes TO supervisor;
GRANT SELECT ON TABLE public.regioncodes TO "90-KEM";
GRANT SELECT ON TABLE public.regioncodes TO "20-HCC";
GRANT SELECT,INSERT,UPDATE ON TABLE public.regioncodes TO mkt;
GRANT SELECT ON TABLE public.regioncodes TO "OZC-HOME";


--
-- Name: TABLE routers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.routers TO eng;
GRANT SELECT ON TABLE public.routers TO mkt;
GRANT SELECT ON TABLE public.routers TO mfg;
GRANT SELECT ON TABLE public.routers TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.routers TO supervisor;


--
-- Name: TABLE securitysectiondetail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.securitysectiondetail TO eng;
GRANT SELECT ON TABLE public.securitysectiondetail TO mkt;
GRANT SELECT ON TABLE public.securitysectiondetail TO mfg;
GRANT SELECT ON TABLE public.securitysectiondetail TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.securitysectiondetail TO supervisor;


--
-- Name: TABLE securitysections; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.securitysections TO eng;
GRANT SELECT ON TABLE public.securitysections TO mkt;
GRANT SELECT ON TABLE public.securitysections TO mfg;
GRANT SELECT ON TABLE public.securitysections TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.securitysections TO supervisor;


--
-- Name: TABLE seriallotnumbers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.seriallotnumbers TO eng;
GRANT SELECT ON TABLE public.seriallotnumbers TO mkt;
GRANT SELECT ON TABLE public.seriallotnumbers TO mfg;
GRANT SELECT ON TABLE public.seriallotnumbers TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.seriallotnumbers TO supervisor;


--
-- Name: TABLE shiftdowntime; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.shiftdowntime TO eng;
GRANT SELECT ON TABLE public.shiftdowntime TO mkt;
GRANT SELECT ON TABLE public.shiftdowntime TO mfg;
GRANT SELECT ON TABLE public.shiftdowntime TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.shiftdowntime TO supervisor;


--
-- Name: TABLE shipviacodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.shipviacodes TO eng;
GRANT SELECT ON TABLE public.shipviacodes TO mkt;
GRANT SELECT ON TABLE public.shipviacodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.shipviacodes TO supervisor;
GRANT SELECT,INSERT,UPDATE ON TABLE public.shipviacodes TO mfg;


--
-- Name: TABLE sodetail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sodetail TO eng;
GRANT SELECT ON TABLE public.sodetail TO mkt;
GRANT SELECT ON TABLE public.sodetail TO mfg;
GRANT SELECT ON TABLE public.sodetail TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.sodetail TO supervisor;


--
-- Name: TABLE soheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.soheader TO eng;
GRANT SELECT ON TABLE public.soheader TO mkt;
GRANT SELECT ON TABLE public.soheader TO mfg;
GRANT SELECT ON TABLE public.soheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.soheader TO supervisor;


--
-- Name: TABLE stocklocations; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.stocklocations TO eng;
GRANT SELECT ON TABLE public.stocklocations TO mkt;
GRANT SELECT ON TABLE public.stocklocations TO mfg;
GRANT SELECT ON TABLE public.stocklocations TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.stocklocations TO supervisor;


--
-- Name: TABLE suocodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.suocodes TO eng;
GRANT SELECT ON TABLE public.suocodes TO mkt;
GRANT SELECT ON TABLE public.suocodes TO mfg;
GRANT SELECT ON TABLE public.suocodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.suocodes TO supervisor;


--
-- Name: TABLE supplieraddress; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.supplieraddress TO eng;
GRANT SELECT ON TABLE public.supplieraddress TO mkt;
GRANT SELECT ON TABLE public.supplieraddress TO mfg;
GRANT SELECT ON TABLE public.supplieraddress TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.supplieraddress TO supervisor;


--
-- Name: TABLE suppliercontacts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.suppliercontacts TO eng;
GRANT SELECT ON TABLE public.suppliercontacts TO mkt;
GRANT SELECT ON TABLE public.suppliercontacts TO mfg;
GRANT SELECT ON TABLE public.suppliercontacts TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.suppliercontacts TO supervisor;


--
-- Name: TABLE suppliers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.suppliers TO eng;
GRANT SELECT ON TABLE public.suppliers TO mkt;
GRANT SELECT ON TABLE public.suppliers TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.suppliers TO supervisor;
GRANT SELECT ON TABLE public.suppliers TO mfg;


--
-- Name: TABLE syskeys; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.syskeys TO eng;
GRANT SELECT ON TABLE public.syskeys TO mkt;
GRANT SELECT ON TABLE public.syskeys TO mfg;
GRANT SELECT ON TABLE public.syskeys TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.syskeys TO supervisor;


--
-- Name: TABLE taxcodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.taxcodes TO eng;
GRANT SELECT ON TABLE public.taxcodes TO mkt;
GRANT SELECT ON TABLE public.taxcodes TO mfg;
GRANT SELECT ON TABLE public.taxcodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.taxcodes TO supervisor;
GRANT SELECT,INSERT,UPDATE ON TABLE public.taxcodes TO "40-NAW";


--
-- Name: TABLE termscodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.termscodes TO eng;
GRANT SELECT ON TABLE public.termscodes TO mkt;
GRANT SELECT ON TABLE public.termscodes TO mfg;
GRANT SELECT ON TABLE public.termscodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.termscodes TO supervisor;


--
-- Name: TABLE transactiondetail; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.transactiondetail TO eng;
GRANT SELECT ON TABLE public.transactiondetail TO mkt;
GRANT SELECT ON TABLE public.transactiondetail TO mfg;
GRANT SELECT ON TABLE public.transactiondetail TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.transactiondetail TO supervisor;


--
-- Name: TABLE transactionheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.transactionheader TO eng;
GRANT SELECT ON TABLE public.transactionheader TO mkt;
GRANT SELECT ON TABLE public.transactionheader TO mfg;
GRANT SELECT ON TABLE public.transactionheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.transactionheader TO supervisor;


--
-- Name: TABLE uomcodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.uomcodes TO eng;
GRANT SELECT ON TABLE public.uomcodes TO mkt;
GRANT SELECT ON TABLE public.uomcodes TO mfg;
GRANT SELECT ON TABLE public.uomcodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.uomcodes TO supervisor;


--
-- Name: TABLE wipissues; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.wipissues TO eng;
GRANT SELECT ON TABLE public.wipissues TO mkt;
GRANT SELECT ON TABLE public.wipissues TO mfg;
GRANT SELECT ON TABLE public.wipissues TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.wipissues TO supervisor;


--
-- Name: TABLE woheader; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.woheader TO eng;
GRANT SELECT ON TABLE public.woheader TO mkt;
GRANT SELECT ON TABLE public.woheader TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.woheader TO supervisor;
GRANT SELECT ON TABLE public.woheader TO mfg;


--
-- Name: TABLE workcenters; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.workcenters TO eng;
GRANT SELECT ON TABLE public.workcenters TO mkt;
GRANT SELECT ON TABLE public.workcenters TO mfg;
GRANT SELECT ON TABLE public.workcenters TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.workcenters TO supervisor;


--
-- Name: TABLE workcentershifts; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.workcentershifts TO eng;
GRANT SELECT ON TABLE public.workcentershifts TO mkt;
GRANT SELECT ON TABLE public.workcentershifts TO mfg;
GRANT SELECT ON TABLE public.workcentershifts TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.workcentershifts TO supervisor;


--
-- Name: TABLE woshortages; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.woshortages TO eng;
GRANT SELECT ON TABLE public.woshortages TO mkt;
GRANT SELECT ON TABLE public.woshortages TO mfg;
GRANT SELECT ON TABLE public.woshortages TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.woshortages TO supervisor;


--
-- Name: TABLE zipcodes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.zipcodes TO eng;
GRANT SELECT ON TABLE public.zipcodes TO mkt;
GRANT SELECT ON TABLE public.zipcodes TO mfg;
GRANT SELECT ON TABLE public.zipcodes TO purch;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.zipcodes TO supervisor;


--
-- PostgreSQL database dump complete
--

\unrestrict 1Mg1Weq1Ys9sBXKSrbcU3wvf1S42eBfyN5X3rvA8Zirb9SxDngN7v7eTK2fCnOr

