CREATE OR REPLACE PROCEDURE enzo.prt_queimaolarias (
    pdata DATE,
    pemp  VARCHAR2
) AS

    vdata       DATE := pdata;
    vemp        VARCHAR2(3) := pemp;
    vnomeolaria VARCHAR2(150);
    vcodipessol NUMBER;
    vqtde       NUMBER;
    vstatus     VARCHAR2(20);
    vnumeesto   NUMBER;
    vcodiesto   NUMBER;
    vcodigene   NUMBER;
BEGIN
    -- Buscar empresa logada para comparar
    SELECT
        e.fantempr
    INTO vnomeolaria
    FROM
        sag.pogeempr e
    WHERE
        e.pcodempr = retopemp();

    SELECT
        c.codipess
    INTO vcodipessol
    FROM
        sag.pogepess c
    WHERE
        upper(c.fantpess) = upper(vnomeolaria);

    SELECT
        MAX(e.numeesto)
    INTO vnumeesto
    FROM
        sag.pogeesto e
    WHERE
        e.pempesto = retopemp();

    -- Buscar dados apontados no GSO
    SELECT
        SUM(t.qtenforna),
        MAX(p.situacao)
    INTO
        vqtde,
        vstatus
    FROM
             dev.enforna p
        INNER JOIN dev.enfornaproduto t ON p.cdenforna = t.cdenforna
        INNER JOIN sag.pocaprod       k ON t.cdproduto = k.codiprod
    WHERE
            trunc(p.dtenforna) = vdata
        AND p.situacao = 'QUEIMA'
        AND upper(p.nomeolaria) = upper(vnomeolaria);

    -- Testar se dia já fechado produção
    IF vqtde IS NOT NULL THEN
        IF vstatus IS NOT NULL THEN
            IF sag.fun_validata(vdata, vdata, 'ES-Estoque') <> 0 THEN  
                -- Buscar na seq o próximo codiesto para gerar mov
                SELECT
                    seq_pogeesto.NEXTVAL
                INTO vcodiesto
                FROM
                    dual;

                SELECT
                    alan.codigene_olarias.nextval
                INTO vcodigene
                FROM
                    dual;

                -- Gravar POGEESTO
                INSERT INTO sag.pogeesto (
                    codiesto,
                    codipess,
                    coditpmv,
                    codiseto,
                    emisesto,
                    receesto,
                    tercesto,
                    situesto,
                    qttoesto,
                    inqpesto,
                    inqresto,
                    numeesto,
                    codigene,
                    tabeesto,
                    compesto
                ) VALUES (
                    vcodiesto,
                    vcodipessol,
                    3206,
                    568,
                    vdata,
                    vdata,
                    0,
                    'QUEIMA',
                    vqtde,
                    vqtde,
                    vqtde,
                    vnumeesto,
                    vcodigene,
                    'SITUOLAR',
                    'Situação queima olaria'
                );

                -- Gravar POCAMVES
                INSERT INTO sag.pocamves (
                    codiesto,
                    codiprod,
                    codiunid,
                    qtnomves,
                    valomves,
                    qtbamves,
                    qttomves,
                    compmves,
                    calcmmves,
                    custmves,
                    coditpmv,
                    datamves,
                    codiseto,
                    coesprod,
                    codigene
                )
                    SELECT
                        vcodiesto,
                        t.cdproduto,
                        2,
                        t.qtenforna,
                        0,
                        t.qtenforna,
                        t.qtenforna,
                        'Situação queima olaria',
                        t.qtenforna,
                        0,
                        3206,
                        vdata,
                        568,
                        t.cdproduto,
                        p.cdenforna
                    FROM
                             dev.enforna p
                        JOIN dev.enfornaproduto t ON p.cdenforna = t.cdenforna
                    WHERE
                            trunc(p.dtenforna) = vdata
                        AND upper(p.nomeolaria) = upper(vnomeolaria);

                -- Commit das operações
                COMMIT;
            ELSE
                raise_application_error(-20000, 'Mov. Estoque: Inclusão Inválida! Período Fechado. (Estoques)');
            END IF;

        ELSE
            raise_application_error(-20343, 'Produção já Fechada!');
        END IF;
    ELSE
        raise_application_error(-20342, 'Não existe produção para o dia!');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Desfaz todas as mudanças se algum erro ocorrer
        ROLLBACK;
        RAISE;
END;
/