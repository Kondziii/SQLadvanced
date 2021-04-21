
/*
Autorzy:
Konrad Chojnacki 224274
Igor Forenc 224294
*/


----------------------------------------ZAPYTANIA-----------------------------------------

USE fabryka_samochodow;
GO

/*
1. Wypisz wszystkie dzia³y których œrednia zarobków pracowników jest wy¿sza b¹d¿ równa œredniemu wynagrodzeniu w fabryce 
oraz podaj ile te dzia³y zatrudniaj¹ pracowników.
*/

SELECT
	p.id_dzialu
   ,d.przeznaczenie
   ,ROUND(AVG(p.wynagrodzenie + ISNULL(p.premie, 0)), 2) AS srednie_wynagrodzenie
   ,COUNT(*) AS liczba_pracownikow
FROM pracownicy p
	,dzialy d
WHERE p.id_dzialu = d.id_dzialu
AND p.data_zwol IS NULL
GROUP BY p.id_dzialu
		,d.przeznaczenie
HAVING AVG(p.wynagrodzenie) >= (SELECT
		AVG(p1.wynagrodzenie + ISNULL(p1.premie, 0))
	FROM pracownicy p1
	WHERE p1.data_zwol IS NULL)
GO

/*
2. Wypisz informacje o pracownikach, którzy brali udzia³ przy produkcji najdro¿szego egzemplarza samochodu 
i podaj ile godzin spêdzili podczas pracy nad nim oraz jaki procent ca³kowitego czasu produkcji stanowi³a ich robota.
*/

SELECT
	p.imie
   ,p.nazwisko
   ,p.wynagrodzenie
   ,s.nazwa
   ,d.przeznaczenie
   ,ds.sredni_czas AS liczba_godzin_pracy
   ,ROUND(CAST(ds.sredni_czas AS FLOAT) / (SELECT
			SUM(ds1.sredni_czas)
		FROM dzialy_samochody ds1
		WHERE ds1.id_samochodu IN (SELECT
				e.id_samochodu
			FROM dbo.egzemplarze AS e
			WHERE e.cena = (SELECT
					MAX(e2.cena)
				FROM dbo.egzemplarze AS e2)))
	, 4) * 100 AS procent_czasu_produkcji
FROM dbo.pracownicy p
	,dbo.dzialy d
	,dbo.stanowiska s
	,dbo.dzialy_samochody ds
WHERE p.id_stanowiska = s.id_stanowiska
AND p.id_dzialu = d.id_dzialu
AND ds.id_dzialu = d.id_dzialu
AND ds.id_samochodu IN (SELECT
		e.id_samochodu
	FROM dbo.egzemplarze AS e
	WHERE e.cena = (SELECT
			MAX(e2.cena)
		FROM dbo.egzemplarze AS e2))
ORDER BY d.przeznaczenie
GO

/*
3. Jeden z pracownikow ma dostaæ awans i mieæ kilkoro pracowników pod sob¹ w dziale Lakiernictwa. Napisz zapytanie, które
wska¿e najbardziej sprawiedliwe wynagrodzenie dla takiego pracownika po awansie bior¹c pod uwagê, ¿e nadal bêdzie zatrudniony
w dziale zajmuj¹cym siê lakiernictwem.
*/

SELECT
	AVG(p.wynagrodzenie) AS sugerowane_wynagrodzenie
FROM dbo.pracownicy AS p
	,dzialy d
WHERE p.id_dzialu = d.id_dzialu
AND d.przeznaczenie = 'Lakiernictwo'
AND EXISTS (SELECT
		*
	FROM dbo.pracownicy AS p2
	WHERE p.id_pracownika = p2.id_kierownika
	AND p.id_dzialu != 'Z01')
GO

/*
4. Wypisz dzia³y, które uczestnicz¹ w produkcji wszystkich modeli samochodów.
*/

SELECT
	d.id_dzialu
   ,d.przeznaczenie
   ,d.hala
FROM dbo.dzialy AS d
WHERE NOT EXISTS (SELECT
		*
	FROM dbo.samochody AS s
	WHERE NOT EXISTS (SELECT
			*
		FROM dbo.dzialy_samochody AS ds
		WHERE ds.id_dzialu = d.id_dzialu
		AND s.id_samochodu = ds.id_samochodu));
GO

/*
5. Podaj ile pracowników zosta³o zatrudnionych po 1 lutym 2010 roku.
*/

BEGIN
	DECLARE @data DATE = '2010/02/01'

	SELECT
		COUNT(*) AS liczba_zatrudnionych
	FROM (SELECT
			p.id_pracownika
		FROM pracownicy p
		WHERE NOT EXISTS (SELECT
				*
			FROM pracownicy_historia ph
			WHERE ph.id_pracownika = p.id_pracownika)
		AND p.data_zatr > @data
		UNION
		(SELECT DISTINCT
			ph.id_pracownika
		FROM pracownicy_historia ph
		WHERE ph.id_pracownika IN (SELECT
				p.id_pracownika
			FROM pracownicy p)
		AND ph.data_zatr > @data)) tab
END
GO

/*
6.Unia Europejska narzuca promowanie silników elektrycznych oraz benzynowych. Napisz zapytanie które sprawdzi 
ile zosta³o zakupionych egzemplarzy samochodów w zale¿noœci od paliwa napêdzaj¹cego zamontowany w nich silnik
oraz ile œrednio trzeba za nie zap³aciæ(nie uwzglêdniaj¹c rabatu) oraz wyœwietli œredni¹ rabatów jaka jest
udzielana na zakup tych samochodów.
*/

SELECT
	s.rodzaj_paliwa
   ,COUNT(*) AS liczba_sprzedanych_egz
   ,ROUND(AVG(e.cena), 2) AS srednia_cena
   ,ROUND(AVG(ISNULL(z.rabat, 0)), 2) AS sredni_rabat
FROM silniki s
	,egzemplarze e
	,egzemplarze_zamowienia ez
	,zamowienia z
WHERE s.id_silnika = e.id_silnika
AND ez.id_egzemplarza = e.id_egzemplarza
AND ez.id_zamowienia = z.id_zamowienia
GROUP BY s.rodzaj_paliwa
GO
/*
7. Wypisz dane pracowników wraz z hierarchi¹ zatrudnienia.
*/

WITH Podlegli (id_kierownika, id_pracownika, imie, nazwisko, HierarchiaZatrudnienia)
AS
(SELECT
		id_kierownika
	   ,id_pracownika
	   ,imie
	   ,nazwisko
	   ,0 AS HierarchiaZatrudnienia
	FROM dbo.pracownicy
	WHERE id_kierownika IS NULL AND data_zwol IS null
	UNION ALL
	SELECT
		p.id_kierownika
	   ,p.id_pracownika
	   ,p.imie
	   ,p.nazwisko
	   ,HierarchiaZatrudnienia + 1
	FROM dbo.pracownicy AS p
	INNER JOIN Podlegli AS p2
		ON p.id_kierownika = p2.id_pracownika)
SELECT
	id_kierownika
   ,id_pracownika
   ,imie
   ,nazwisko
   ,HierarchiaZatrudnienia =
	CASE
		WHEN p.HierarchiaZatrudnienia = 0 THEN 'Dyrektor zak³adu'
		WHEN p.HierarchiaZatrudnienia = 1 THEN 'Kierownik dzialu'
		WHEN p.HierarchiaZatrudnienia = 2 THEN 'Kierownik poddzialu'
		WHEN p.HierarchiaZatrudnienia = 3 THEN 'Pracownik fizyczny'
		ELSE 'Pracownik'
	END
FROM Podlegli AS p
ORDER BY id_kierownika;
GO

/*
8. Rozwa¿ane jest wprowadzenie specjalnej oferty dla firm zaprzyjaŸnionych. Napisz zapytanie które wyœwietli dane kontaktowe przedstawicieli
firm, które ju¿ zamówili wiêcej ni¿ trzy samochody z fabryki i wskaze jak¹ marka i modelem siê oni g³ownie interesowali(jakich najwiêcej kupili).
*/

SELECT
	q1.id_klienta
   ,q1.imie
   ,q1.nazwisko
   ,q1.nr_telefonu
   ,q1.email
   ,CONCAT(q2.marka, ' ', q2.model) AS najczesciej_kupowany_model
FROM (SELECT
		k1.id_klienta
	   ,k1.imie
	   ,k1.nazwisko
	   ,k1.nr_telefonu
	   ,k1.email
	   ,COUNT(*) AS liczba_zakupionych_egz
	FROM klienci k1
		,zamowienia z
		,egzemplarze_zamowienia ez
	WHERE k1.id_klienta = z.id_klienta
	AND z.id_zamowienia = ez.id_zamowienia
	AND k1.typ_klienta = 'firma'
	GROUP BY k1.id_klienta
			,k1.imie
			,k1.nazwisko
			,k1.nr_telefonu
			,k1.email
	HAVING COUNT(*) > 3) q1
JOIN (SELECT
		s.marka
	   ,s.model
	   ,k.id_klienta
	   ,RANK() OVER (PARTITION BY k.id_klienta ORDER BY COUNT(*) DESC) AS kolejnosc
	FROM egzemplarze e
		,egzemplarze_zamowienia ez
		,samochody s
		,zamowienia z
		,klienci k
	WHERE e.id_egzemplarza = ez.id_egzemplarza
	AND e.id_samochodu = s.id_samochodu
	AND z.id_zamowienia = ez.id_zamowienia
	AND z.id_klienta = k.id_klienta
	AND k.typ_klienta = 'firma'
	GROUP BY s.marka
			,s.model
			,k.id_klienta) q2
	ON q1.id_klienta = q2.id_klienta
WHERE q2.kolejnosc = 1
GO

/*
9. Wypisz 3 klientów, których stosunek wartoœci zamówionych egzemplarzy samochodów do sumarycznego otrzymanego rabatu jest najni¿szy
(czyli tych którzy otrzymali wysoki rabat w stosunku do zakupionych egzemplarzy samochodów).
*/

WITH wartoscDoRabatu (id_klienta, wartosc_pojazdu_do_rabatu)
AS
(SELECT TOP 3 WITH TIES
		z.id_klienta
	   ,SUM(e.cena) / (SUM(z.rabat) / COUNT(ez.id_zamowienia)) AS wartosc_pojazdu_do_rabatu
	FROM dbo.klienci k
		,dbo.zamowienia z
		,dbo.egzemplarze_zamowienia ez
		,dbo.egzemplarze e
	WHERE k.id_klienta = z.id_klienta
	AND z.id_zamowienia = ez.id_zamowienia
	AND ez.id_egzemplarza = e.id_egzemplarza
	AND z.rabat != 0
	GROUP BY z.id_klienta
	ORDER BY wartosc_pojazdu_do_rabatu)
SELECT
	k.imie
   ,k.nazwisko
   ,k.id_klienta
   ,x.wartosc_pojazdu_do_rabatu
FROM klienci k
	,wartoscDoRabatu x
WHERE x.id_klienta = k.id_klienta
GO

/*
10. Planowane jest wprowadzenie usprawnieñ w produkcji w tym celu napisz zapytanie które
wypisze dla poszczególnych modeli samochodów dzia³y, w których spêdzaj¹ najwiêcej czasu podczas produkcji.
*/

SELECT
	k.id_samochodu
   ,s.marka
   ,s.model
   ,k.id_dzialu
   ,k.sredni_czas AS czas_przebywania_na_dziale
FROM (SELECT
			 ds2.id_samochodu
			,ds2.id_dzialu
			,ds2.sredni_czas
			,RANK() OVER (PARTITION BY ds2.id_samochodu
			 ORDER BY ds2.sredni_czas DESC) AS kolejnosc
		 FROM dbo.dzialy_samochody AS ds2) AS k
	,dbo.samochody AS s
WHERE k.kolejnosc = 1
AND k.id_samochodu = s.id_samochodu;
GO


/*
11. Napisz zapytanie które wyliczy ca³kowite wartoœci zamówieñ z³o¿onych w roku 2020 wraz z uwzglêdnionym rabatem oraz poda 
informacje o tym czy zamowienie by³o na firme czy dla klienta indywidualnego, uszereguje zamówienia od
najdro¿szego do najtañszego.
*/

SELECT 
	ez.id_zamowienia
   ,SUM(e.cena) - ISNULL(z.rabat, 0) AS calkowity_koszt
   ,k.typ_klienta
FROM dbo.egzemplarze_zamowienia ez
	,dbo.egzemplarze e
	,dbo.zamowienia z
	,dbo.klienci k
WHERE ez.id_egzemplarza = e.id_egzemplarza
AND ez.id_zamowienia = z.id_zamowienia
AND k.id_klienta = z.id_klienta
AND DATEPART(YEAR, z.data_zamowienia) = 2020
GROUP BY ez.id_zamowienia
		,z.rabat
		,k.typ_klienta
ORDER BY calkowity_koszt DESC;
GO

/*
12. Rozwa¿ane jest przeprowadzenie liftingu s³abo sprzedaj¹cych siê modeli w tym celu napisz
zapytanie które wyœwietli modele samochodów i ich procentow¹ sprzeda¿.
*/

SELECT
	query.marka
   ,query.model
   ,ROUND(CAST(query.liczba_samochodow AS FLOAT) / (SELECT
			COUNT(*)
		FROM dbo.egzemplarze_zamowienia ez2
			,dbo.egzemplarze e
			,dbo.samochody s
		WHERE ez2.id_egzemplarza = e.id_egzemplarza
		AND s.id_samochodu = e.id_samochodu)
	, 4) * 100 AS udzial_procentowy
FROM (SELECT
		s.marka
	   ,s.model
	   ,COUNT(*) AS liczba_samochodow
	FROM dbo.samochody s
		,dbo.egzemplarze e
		,dbo.egzemplarze_zamowienia ez
	WHERE s.id_samochodu = e.id_samochodu
	AND e.id_egzemplarza = ez.id_egzemplarza
	GROUP BY s.marka
			,s.model) AS query
ORDER BY udzial_procentowy ASC;
GO


/*
13. Przychodzi klient, który chce zamówiæ samochód w modnym kolorze, napisz zapytanie
które wyœwietli 3 najczêsciej wybierane kolory oraz podaj jaki procent sprzeda¿y one stanowi³y.

*/

SELECT
	query.kolor
   ,query.liczba_egzemplarzy
   ,ROUND(CAST(query.liczba_egzemplarzy AS FLOAT) / (SELECT
			COUNT(*)
		FROM dbo.egzemplarze_zamowienia ez2
			,dbo.egzemplarze e2
		WHERE ez2.id_egzemplarza = e2.id_egzemplarza)
	, 4) * 100 AS procent
FROM (SELECT TOP 3 WITH TIES
		e.kolor
	   ,COUNT(*) AS liczba_egzemplarzy
	FROM dbo.egzemplarze e
		,dbo.egzemplarze_zamowienia ez
	WHERE e.id_egzemplarza = ez.id_egzemplarza
	GROUP BY e.kolor
	ORDER BY liczba_egzemplarzy DESC) AS query;
GO

/*
14. Wyœwietl informacje o dzia³ach - ile zatrudniaj¹ pracowników oraz ile sumarycznie pieniêdzy przeznaczaj¹ 
na zarobki dla swoich pracowników, uszereguj je malej¹co wzglêdem obliczonych sum.
*/

SELECT
	d2.id_dzialu
   ,d2.przeznaczenie
   ,(SELECT
			COUNT(*) AS liczba_pracownikow
		FROM dbo.pracownicy AS p
			,dbo.dzialy AS d
		WHERE p.id_dzialu = d.id_dzialu
		AND d.id_dzialu = d2.id_dzialu
		AND p.data_zwol IS NULL
		GROUP BY d.id_dzialu)
	AS liczba_pracownikow
   ,SUM(p2.wynagrodzenie + ISNULL(p2.premie, 0)) AS suma_na_zarobki_pracownikow
FROM dbo.dzialy AS d2
	,dbo.pracownicy AS p2
WHERE d2.id_dzialu = p2.id_dzialu
AND p2.data_zwol IS NULL
GROUP BY d2.id_dzialu
		,d2.przeznaczenie
ORDER BY suma_na_zarobki_pracownikow DESC;
GO

/*
15. Podaj nazwy stanowisk na których pracownicy œrednio zarabiaj¹ nie mniej ni¿ œrednie wynagrodzenie dla ca³ej fabryki, 
podaj to wynagrodzenie.
*/

SELECT
	s.nazwa
   ,ROUND(AVG(p.wynagrodzenie), 2) AS srednie_wynagrodzenie
FROM dbo.pracownicy AS p
	,dbo.stanowiska AS s
WHERE s.id_stanowiska = p.id_stanowiska
AND p.data_zwol IS NULL
GROUP BY s.nazwa
HAVING AVG(p.wynagrodzenie) >= (SELECT
		AVG(p2.wynagrodzenie + ISNULL(p2.premie, 0))
	FROM dbo.pracownicy AS p2
	WHERE p2.data_zwol IS NULL);
GO

----------------------------------------PROCEDURY-----------------------------------------
/*
1. Niestety og³oszno, ¿e realizacja zamówieñ z £odzi siê przed³u¿y, napisz procedurê która podniesie 
rabat niezrealizowanym og³oszeniom z £odzi o 2000 z³ jako rekompensatê d³u¿szego czasu oczekiwania na samochód.
*/

SELECT
	*
FROM dbo.zamowienia z;
GO
CREATE PROCEDURE zwiekszRabat (@miasto VARCHAR(50),
@rabat MONEY)
AS
BEGIN
	DECLARE @id_zam INT;
	DECLARE kursor CURSOR FOR (SELECT
			z.id_zamowienia
		FROM dbo.zamowienia z
		WHERE z.data_realizacji IS NULL
		AND z.adres LIKE @miasto + '%');
	OPEN kursor;
	FETCH NEXT FROM kursor INTO @id_zam;
	WHILE @@fetch_status = 0
	BEGIN
	UPDATE dbo.zamowienia
	SET dbo.zamowienia.rabat = dbo.zamowienia.rabat + @rabat
	WHERE dbo.zamowienia.id_zamowienia = @id_zam;
	PRINT 'Podwyzszono rabat o ' + CAST(@rabat AS VARCHAR(30)) + ' dla zamowienia o id ' + CAST(@id_zam AS VARCHAR(5));
	FETCH NEXT FROM kursor INTO @id_zam;
	END;
	CLOSE kursor;
	DEALLOCATE kursor;
END;
GO
EXEC zwiekszRabat '£ódŸ'
				 ,2000;
GO
SELECT
	*
FROM dbo.zamowienia z;
GO

/*
2. Dzia³ M12 zosta³ doceniony i przyznano mu 1000 zl podwy¿ki. Napisz procedure która rozdzieli te sumê 
pomiêdzy pracowników dzia³u pamietaj¹c o tym, ¿e kierownicy tego dzialu dostaj¹ 2 razy wieksz¹ podwy¿kê ni¿ pracownicy fizyczni.
*/

SELECT
	*
FROM dbo.pracownicy p;
GO
CREATE PROCEDURE zwiekszWynagrodzenieDlaDzialu (@id_dzialu VARCHAR(3),
@suma MONEY,
@stosunek FLOAT = 2)
AS
BEGIN
	DECLARE @kierownicy INT
		   ,@pracownicy INT;
	SET @kierownicy = (SELECT
			COUNT(*)
		FROM dbo.pracownicy p
		WHERE p.id_dzialu = @id_dzialu
		AND p.data_zwol IS NULL
		AND EXISTS (SELECT
				*
			FROM dbo.pracownicy p2
			WHERE p2.id_kierownika = p.id_pracownika
			AND p2.data_zwol IS NULL));
	SET @pracownicy = (SELECT
			COUNT(*)
		FROM dbo.pracownicy p
		WHERE p.id_dzialu = @id_dzialu
		AND p.data_zwol IS NULL)
	- @kierownicy;
	DECLARE @podwyzka MONEY;
	SET @podwyzka = @suma / (@kierownicy * @stosunek + @pracownicy);
	UPDATE dbo.pracownicy
	SET dbo.pracownicy.wynagrodzenie = dbo.pracownicy.wynagrodzenie + @podwyzka * @stosunek
	WHERE dbo.pracownicy.id_dzialu = @id_dzialu
	AND dbo.pracownicy.data_zwol IS NULL
	AND EXISTS (SELECT
			*
		FROM dbo.pracownicy p
		WHERE p.id_kierownika = dbo.pracownicy.id_pracownika
		AND p.data_zwol IS NULL);
	UPDATE dbo.pracownicy
	SET dbo.pracownicy.wynagrodzenie = dbo.pracownicy.wynagrodzenie + @podwyzka
	WHERE dbo.pracownicy.id_dzialu = @id_dzialu
	AND dbo.pracownicy.data_zwol IS NULL
	AND NOT EXISTS (SELECT
			*
		FROM dbo.pracownicy p
		WHERE p.id_kierownika = dbo.pracownicy.id_pracownika
		AND p.data_zwol IS NULL);
END;
GO
EXEC zwiekszWynagrodzenieDlaDzialu 'M12'
								  ,1000
SELECT
	*
FROM dbo.pracownicy p;
GO

/*
3. Og³oszono, ¿e silnik o id 8 montowany w samochodach po 2012 roku ma wadê fabryczna.
Napisz procedurê, która wyœwietli dane kontaktowe klientów którzy nabyli samochód z tym silnikiem oraz z¹stapi
aktualnie produkowane egzemplarze z tym silnikiem silnikiem o id 14.
*/


CREATE PROCEDURE powiadom_o_wadzie (@id_silnika INT, @year INT, @id_silnika_nowego INT)
AS
BEGIN

	SELECT DISTINCT
		k.imie
	   ,k.nazwisko
	   ,k.nr_telefonu
	   ,k.email
	   ,Z.adres
	FROM klienci k
		,zamowienia Z
		,egzemplarze_zamowienia ez
	WHERE Z.id_klienta = k.id_klienta
	AND YEAR(Z.data_zamowienia) - 2012 > 0
	AND Z.data_realizacji IS NOT NULL
	AND Z.id_zamowienia = ez.id_zamowienia
	AND ez.id_egzemplarza IN (SELECT
			e.id_egzemplarza
		FROM egzemplarze e
		WHERE e.id_silnika IN (SELECT
				s.id_silnika
			FROM silniki s))

	UPDATE egzemplarze
	SET id_silnika = @id_silnika_nowego
	WHERE id_egzemplarza IN (SELECT
			e.id_egzemplarza
		FROM egzemplarze e
		WHERE e.id_silnika = @id_silnika)

	PRINT 'Zmodyfikowano ' + CAST(@@rowcount AS VARCHAR(20)) + ' rekordów.'

END
GO

EXEC powiadom_o_wadzie 8
					  ,2012
					  ,14
SELECT
	*
FROM egzemplarze e
GO
/*
4. Napisz procedurê, która dla podanego jako argument id pracownika wyœwietli wszystkie egzemplarze samochodów,
w których produkcji bierze udzia³ i wypisze informacje o ich iloœci, a
w przypadku gdy pracownik nie bierze udzia³u w produkcji ¿adnego samochodu wypisze stosown¹ informacjê.
*/

CREATE PROCEDURE wyswietlSamochodyPracownika (@id_pracownika INT)
AS
BEGIN
	DECLARE @ile INT = 0;
	SET @ile = (SELECT
			COUNT(*)
		FROM dbo.samochody s
			,dbo.dzialy_samochody ds
			,dbo.dzialy d
			,dbo.pracownicy p
		WHERE s.id_samochodu = ds.id_samochodu
		AND ds.id_dzialu = d.id_dzialu
		AND p.id_dzialu = d.id_dzialu
		AND p.id_pracownika = @id_pracownika);
	PRINT CAST(@ile AS VARCHAR(20));
	IF @ile = 0
	BEGIN
		PRINT 'Pracownik o id ' + CAST(@id_pracownika AS VARCHAR(20)) + ' nie bierze udzia³u w produkcji ¿adnego samochodu.';
	END;
	ELSE
	BEGIN
		PRINT 'Pracownik o id ' + CAST(@id_pracownika AS VARCHAR(20)) + ' bierze udzia³u w produkcji ' + CAST(@ile AS VARCHAR(4)) + ' samochodów.';
		SELECT
			e.id_egzemplarza
		   ,s.marka
		   ,s.model
		   ,e.rodzaj_wyposazenia
		   ,e.kolor
		   ,e.typ_nadwozia
		   ,e.liczba_drzwi
		FROM dbo.samochody s
			,dbo.dzialy_samochody ds
			,dbo.dzialy d
			,dbo.pracownicy p
			,dbo.egzemplarze e
		WHERE s.id_samochodu = ds.id_samochodu
		AND ds.id_dzialu = d.id_dzialu
		AND p.id_dzialu = d.id_dzialu
		AND p.id_pracownika = @id_pracownika
		AND e.id_samochodu = s.id_samochodu
	END;
END;
GO
EXEC wyswietlSamochodyPracownika 12;
GO

/*
5. Dzia³ M11 jest powoli likwidowany, w tym celu napisz procedurê która przeniesie pracowników tego dzia³u 
do dzia³u maj¹cego takie samo przeznaczenie i zatrudniaj¹cego najmniejsza liczbê pracowników.
*/

CREATE PROCEDURE przenies_pracownikow (@id_dzialu VARCHAR(3))
AS
BEGIN
	DECLARE @dzial_przenoszenia VARCHAR(3)
	SET @dzial_przenoszenia = (SELECT
			s.id_dzialu
		FROM (SELECT TOP 1
				d.id_dzialu
			   ,COUNT(*) AS liczba_pracownikow
			FROM pracownicy p
				,dzialy d
			WHERE p.id_dzialu = d.id_dzialu
			AND d.id_dzialu <> @id_dzialu
			AND d.przeznaczenie = (SELECT
					d1.przeznaczenie
				FROM dzialy d1
				WHERE d1.id_dzialu = @id_dzialu)
			GROUP BY d.id_dzialu
			ORDER BY liczba_pracownikow DESC, d.id_dzialu ASC) s)

	IF @dzial_przenoszenia IS NULL
	BEGIN
		PRINT 'Nie ma dostêpnego dzia³u do którego mo¿na przenieœæ pracowników dzia³u ' + @id_dzialu
		DELETE pracownicy
		WHERE id_dzialu = @id_dzialu
	END
	ELSE
	BEGIN
		DECLARE @id INT
			   ,@imie VARCHAR(50)
			   ,@nazwisko VARCHAR(50)
		DECLARE kursor CURSOR FOR (SELECT
				p.id_pracownika
			   ,p.imie
			   ,p.nazwisko
			FROM pracownicy p
			WHERE p.id_dzialu = @id_dzialu)
		OPEN kursor
		FETCH NEXT FROM kursor INTO @id, @imie, @nazwisko
		WHILE @@fetch_status = 0
		BEGIN
		PRINT 'Pracownika o id ' + CAST(@id AS VARCHAR(10)) + ' ' + @imie + ' ' + @nazwisko + ' przeniesiono do dzia³u ' + @dzial_przenoszenia
		UPDATE pracownicy
		SET id_dzialu = @dzial_przenoszenia
		WHERE id_pracownika = @id

		FETCH NEXT FROM kursor INTO @id, @imie, @nazwisko
		END
		CLOSE kursor
		DEALLOCATE kursor
	END
END
GO

EXEC przenies_pracownikow 'M11'
SELECT
	*
FROM pracownicy p
GO

----------------------------------------FUNKCJE-----------------------------------------

/*
1. Pracownicy z okazji œwi¹t dostaj¹ jednorazowy dodatek do wyngagrodzenia, napisz
funkcjê, która obliczy ten dodatek dla ka¿dego pracownika zgodnie z zasad¹
- jeœli sta¿ pracy jest d³u¿szy lub równy  15 lat pracownik otrzymuje 15% pensji
- jeœli sta¿ pracy jest d³u¿szy lub równy  10 lat ale krótszy niz 15 lat pracownik otrzymuje 10% pensji
- pozostali pracownicy dostaj¹ 5% pensji

*/

CREATE FUNCTION oblicz_dodatek (@id_pracownika INT, @data_zatr DATE, @pensja MONEY)
RETURNS MONEY
AS
BEGIN
	DECLARE @sta¿_pracy INT
		   ,@dodatek MONEY
	SET @sta¿_pracy = YEAR(GETDATE()) - YEAR(@data_zatr)
	SET @sta¿_pracy = @sta¿_pracy + (SELECT
			SUM(DATEDIFF(YEAR, ph.data_zatr, ph.data_zwol))
		FROM pracownicy_historia ph
		WHERE id_pracownika = @id_pracownika)
	IF @sta¿_pracy >= 15
		SET @dodatek = 0.15 * @pensja
	ELSE
	IF @sta¿_pracy >= 10
		SET @dodatek = 0.1 * @pensja
	ELSE
		SET @dodatek = 0.05 * @pensja

	RETURN @dodatek
END
GO

SELECT
	p.imie
   ,p.nazwisko
   ,p.data_zatr
   ,p.wynagrodzenie
   ,dbo.oblicz_dodatek(p.id_pracownika, p.data_zatr, p.wynagrodzenie) AS dodatek_swiateczny
FROM pracownicy p
WHERE p.data_zwol IS NULL
GO

/*
2. Napisz funkcjê, która zwróci procentowy udzia³ danego silnika w zamówionych egzemplarzach samochodów, a nastêpnie wyswietl 
informacje o silnikach uwzglêdniaj¹c napisan¹ funkcjê.
*/

CREATE FUNCTION procentowyUdzialSilnika (@id_silnika INT)
RETURNS FLOAT
AS
BEGIN
	RETURN ISNULL(ROUND(CAST((SELECT
			COUNT(*)
		FROM dbo.egzemplarze e
			,dbo.egzemplarze_zamowienia ez
		WHERE e.id_egzemplarza = ez.id_egzemplarza
		AND e.id_silnika = @id_silnika)
	AS FLOAT) / (SELECT
			COUNT(*)
		FROM dbo.egzemplarze e
			,dbo.egzemplarze_zamowienia ez
		WHERE e.id_egzemplarza = ez.id_egzemplarza)
	, 4) * 100, 0.00);
END;
GO
SELECT
	s.id_silnika
   ,s.nazwa
   ,s.pojemnosc
   ,s.moc
   ,s.rodzaj_paliwa
   ,dbo.procentowyUdzialSilnika(s.id_silnika) AS udzial_w_sprzedazy
FROM dbo.silniki s;
GO

/*
3. Napisz funkcjê, która zwróci informacje o tym czy dany pracownik zarabia powy¿ej czy poni¿ej mediany zarobków w firmie.
*/

CREATE FUNCTION sprawdzCzyWiecejNizMediana (@wynagrodzenie MONEY)
RETURNS VARCHAR(20)
AS
BEGIN
	DECLARE @mediana MONEY;
	SET @mediana = (SELECT
			((SELECT
					MAX(max_value.placa)
				FROM (SELECT
						p.wynagrodzenie + p.premie AS placa
					FROM dbo.pracownicy p
					WHERE p.data_zwol IS NULL) AS max_value)
			+ (SELECT
					MIN(min_value.placa)
				FROM (SELECT
						p2.wynagrodzenie + p2.premie AS placa
					FROM dbo.pracownicy p2
					WHERE p2.data_zwol IS NULL) AS min_value)
			) / 2);
	DECLARE @stan VARCHAR(20);
	IF @wynagrodzenie > @mediana
	BEGIN
		SET @stan = 'Wiêcej';
	END;
	ELSE
	IF @wynagrodzenie = @mediana
		SET @stan = 'Tyle samo';
	ELSE
		SET @stan = 'Mniej';
	RETURN @stan;
END;
GO
SELECT
	p.imie
   ,p.nazwisko
   ,p.data_zatr
   ,p.wynagrodzenie
   ,s.nazwa AS stanowisko
   ,d.przeznaczenie AS przez_dzialu
   ,dbo.sprawdzCzyWiecejNizMediana(p.wynagrodzenie) AS czy_wiecej_od_mediany
FROM dbo.pracownicy p
	,dbo.stanowiska s
	,dbo.dzialy d
WHERE p.id_stanowiska = s.id_stanowiska
AND p.id_dzialu = d.id_dzialu
AND p.data_zwol IS NULL
GO

/*
4. Rozwa¿ane jest wprowadzenie nowego modelu samochodu. W tym celu napisz funkcjê, która 
obliczy dla ka¿dego dzia³u w produkcji jakiej liczby egzemplarzy samochodów bierze udzia³, a nastêpnie
wykorzystuj¹c funkcjê zaproponuje dzia³y najmniej obci¹¿one dla wprowadzenia nowego modelu do produkcji.
*/

CREATE FUNCTION oblicz_liczbe_egz_dzialu (@id_dzialu VARCHAR(3))
RETURNS INT
AS
BEGIN
	DECLARE @ilosc INT = 0
	SET @ilosc = (SELECT
			COUNT(*)
		FROM dzialy d
			,dzialy_samochody ds
			,samochody s
			,egzemplarze e
		WHERE d.id_dzialu = ds.id_dzialu
		AND ds.id_samochodu = s.id_samochodu
		AND e.id_samochodu = s.id_samochodu
		AND d.id_dzialu = @id_dzialu)

	RETURN @ilosc
END
GO

SELECT
	q1.id_dzialu
   ,q1.przeznaczenie
FROM (SELECT
		d.id_dzialu
	   ,d.przeznaczenie
	   ,dbo.oblicz_liczbe_egz_dzialu(d.id_dzialu) AS liczba_produkowanych_egz
	FROM dzialy d) q1
INNER JOIN (SELECT
		d.przeznaczenie
	   ,MIN(dbo.oblicz_liczbe_egz_dzialu(d.id_dzialu)) AS liczba_produkowanych_egz
	FROM dzialy d
	GROUP BY d.przeznaczenie) q2
	ON q1.przeznaczenie = q2.przeznaczenie
		AND q1.liczba_produkowanych_egz = q2.liczba_produkowanych_egz
GO

/*
5. Napisz funkcjê, która okresli status zamówienia, pamiêtaj¹c, ¿e czas realizacji zamówienia powinien wynieœæ maksymalnie oko³o 90 dni, 
a po 30 dniach status zamówienia zmienia sie na pilne je¿eli nie zosta³o jeszcze zrealizowane.
Nastepnie wykorzystaj tê funkcjê do wyœwietlenia egzemplarzy samochodów i ich liczby, 
które niezw³ocznie powinny byæ wyprodukowane.
*/
CREATE FUNCTION czy_pilne (@data_zamowienia DATE, @data_realizacji DATE, @czas_real_sug INT, @punkt_ost INT)
RETURNS VARCHAR(30)
AS
BEGIN
	DECLARE @okres INT
		   ,@status VARCHAR(30)

	IF @data_realizacji IS NOT NULL
		SET @status = 'Zrealizowane'

	ELSE
	BEGIN
		SET @okres = DATEDIFF(DAY, @data_zamowienia, GETDATE())

		IF @okres > @czas_real_sug
			SET @status = 'Bardzo pilne'
		ELSE
		IF @okres BETWEEN @punkt_ost AND @czas_real_sug
			SET @status = 'Pilne'
		ELSE
			SET @status = 'Niepilne'
	END
	RETURN @status
END
GO

SELECT
	q1.id_zamowienia
   ,q1.adres
   ,q2.id_egzemplarza
   ,q2.marka
   ,q2.model
   ,q2.id_silnika
   ,q2.rodzaj_wyposazenia
   ,q2.kolor
   ,q2.typ_nadwozia
   ,q2.liczba_drzwi
   ,COUNT(*) AS ile_sztuk
   ,DENSE_RANK() OVER (ORDER BY q1.data_zamowienia ASC) AS kolejnosc_realizacji
FROM (SELECT
		z.id_zamowienia
	   ,z.adres
	   ,z.data_zamowienia
	   ,ez.id_egzemplarza
	FROM zamowienia z
		,egzemplarze_zamowienia ez
	WHERE z.id_zamowienia = ez.id_zamowienia
	AND dbo.czy_pilne(z.data_zamowienia, z.data_realizacji, 90, 30) = 'Bardzo pilne') q1
JOIN (SELECT
		e.id_egzemplarza
	   ,e.id_silnika
	   ,e.rodzaj_wyposazenia
	   ,e.kolor
	   ,e.typ_nadwozia
	   ,e.liczba_drzwi
	   ,s.model
	   ,s.marka
	FROM egzemplarze e
		,samochody s
	WHERE e.id_samochodu = s.id_samochodu) q2
	ON q1.id_egzemplarza = q2.id_egzemplarza
GROUP BY q1.id_zamowienia
		,q1.adres
		,q2.id_egzemplarza
		,q2.marka
		,q2.model
		,q2.id_silnika
		,q2.rodzaj_wyposazenia
		,q2.kolor
		,q2.typ_nadwozia
		,q2.liczba_drzwi
		,q1.data_zamowienia
ORDER BY q1.data_zamowienia ASC
GO

----------------------------------------WYZWALACZE-----------------------------------------

/*
1. Napisz wyzwalacz, który zamiast zmiany stanowiska pracownika wstawi nowy rekord z danymi pracownika do tabeli pracownicy_historia
z dat¹ zwolnienia ustawion¹ jako data zmiany stanowiska i starym stanowiskiem, a aktualny rekord w tabeli pracownicy 
zmodyfikuje stanowsiko pracownika i ustawi datê zatrudnienia na datê zmiany stanowiska.
*/

CREATE TRIGGER zmiana_stanowiska
ON pracownicy
INSTEAD OF UPDATE
AS
BEGIN
	DECLARE @nowe_stanowisko INT
		   ,@stare_stanowisko INT
		   ,@id INT

	SET @id = (SELECT
			id_pracownika
		FROM DELETED);

	IF (SELECT
				data_zwol
			FROM DELETED)
		IS NULL
	BEGIN
		SET @nowe_stanowisko = (SELECT
				id_stanowiska
			FROM INSERTED)
		SET @stare_stanowisko = (SELECT
				id_stanowiska
			FROM DELETED)
		IF @stare_stanowisko <> @nowe_stanowisko
		BEGIN
			INSERT INTO pracownicy_historia (id_pracownika,
			data_zatr,
			data_zwol,
			wynagrodzenie,
			id_dzialu,
			id_stanowiska)
				SELECT
					id_pracownika
				   ,data_zatr
				   ,GETDATE()
				   ,wynagrodzenie
				   ,id_dzialu
				   ,@stare_stanowisko
				FROM INSERTED


			UPDATE pracownicy
			SET id_stanowiska = @nowe_stanowisko
			   ,data_zatr = GETDATE()
			WHERE id_pracownika = @id

			DECLARE @nazwa_stanowiska VARCHAR(30)
			SET @nazwa_stanowiska = (SELECT
					s.nazwa
				FROM stanowiska s
				WHERE s.id_stanowiska = @nowe_stanowisko)
			PRINT 'Pracownikowi o id ' + CAST(@id AS VARCHAR(10)) + ' zosta³o przypisane stanowisko ' + @nazwa_stanowiska

		END
	END
	ELSE
		PRINT 'Pracownik o id ' + CAST(@id AS VARCHAR(10)) + ' zosta³ zwolniony z fabryki i nie mo¿na mu zmieniæ stanowiska.'
END
GO

-- udana zmiana
UPDATE dbo.pracownicy
SET dbo.pracownicy.id_stanowiska = 13
WHERE dbo.pracownicy.id_pracownika = 60;
GO
SELECT
	*
FROM dbo.pracownicy p;
GO

-- nieudana zmiana
UPDATE dbo.pracownicy
SET dbo.pracownicy.id_stanowiska = 5
WHERE dbo.pracownicy.id_pracownika = 14;
GO
SELECT
	*
FROM dbo.pracownicy p;
GO

/*
2. Napisz wyzwalacz który po wstawieniu egzemplarza modelu jeœli jego cena nie mieœci siê w przedziale cenowym, 
ograniczy cenê do ceny maksymalnej lub minimalnej, zale¿nie od tego czy cena jest za niska czy za wysoka 
oraz wypisze informacje o wykonanych dzia³aniach.
*/

CREATE TRIGGER weryfikujCeneEgzemplarza
ON dbo.egzemplarze
AFTER INSERT
AS
BEGIN
	DECLARE @cena_min MONEY
		   ,@cena_maks MONEY
		   ,@wpisana_cena MONEY
		   ,@id INT;
	SET @id = (SELECT
			i.id_egzemplarza
		FROM INSERTED i);
	SET @cena_maks = (SELECT
			s.cena_max
		FROM dbo.samochody s
			,dbo.egzemplarze e
		WHERE e.id_egzemplarza = @id
		AND s.id_samochodu = e.id_samochodu);
	SET @cena_min = (SELECT
			s.cena_min
		FROM dbo.samochody s
			,dbo.egzemplarze e
		WHERE e.id_egzemplarza = @id
		AND s.id_samochodu = e.id_samochodu);
	SET @wpisana_cena = (SELECT
			i.cena
		FROM INSERTED i);
	IF @wpisana_cena < @cena_min
	BEGIN
		UPDATE dbo.egzemplarze
		SET dbo.egzemplarze.cena = @cena_min
		WHERE dbo.egzemplarze.id_egzemplarza = @id;
		PRINT 'Cena zbyt niska dla egzemplarza o id ' + CAST(@id AS VARCHAR(10)) + ' podwyzszono o ' + CAST((@cena_min - @wpisana_cena) AS VARCHAR(30));
	END;
	ELSE
	IF @wpisana_cena > @cena_maks
	BEGIN
		UPDATE dbo.egzemplarze
		SET dbo.egzemplarze.cena = @cena_maks
		WHERE dbo.egzemplarze.id_egzemplarza = @id;
		PRINT 'Cena zbyt wysoka dla egzemplarza o id ' + CAST(@id AS VARCHAR(10)) + ' obni¿ono o ' + CAST((@wpisana_cena - @cena_maks) AS VARCHAR(30));
	END;
END;
GO
-- za du¿a cena - cena zostanie obni¿ona do maksymalnego progu
INSERT INTO dbo.egzemplarze (id_samochodu,
id_silnika,
rodzaj_wyposazenia,
kolor,
typ_nadwozia,
liczba_drzwi,
cena)
	VALUES (1, 7, 'R-LINE', 'czerwony', 'HATCHBACK', 3, 100000);
GO
SELECT
	*
FROM dbo.egzemplarze e;
GO

-- za niska cena - cena zostanie podwy¿szona do minimalnego progu
INSERT INTO dbo.egzemplarze (id_samochodu,
id_silnika,
rodzaj_wyposazenia,
kolor,
typ_nadwozia,
liczba_drzwi,
cena)
	VALUES (1, 7, 'R-LINE', 'czerwony', 'HATCHBACK', 3, 20000);
GO
SELECT
	*
FROM dbo.egzemplarze e;

-- prawid³owa cena mieszcz¹ca siê w ustalonym przedziale

INSERT INTO dbo.egzemplarze (id_samochodu,
id_silnika,
rodzaj_wyposazenia,
kolor,
typ_nadwozia,
liczba_drzwi,
cena)
	VALUES (1, 7, 'R-LINE', 'czerwony', 'HATCHBACK', 3, 84000);
GO
SELECT
	*
FROM dbo.egzemplarze e;
GO

/*
3. Napisz wyzwalacz który, przy usuwaniu pracownika, który ma podw³adnych, przypisze tych podw³adnych osobie która sprawuje nadzór 
nad t¹ osob¹, któr¹ chce siê usun¹æ, a dodatkwo wypisze informacje o dokonanych zmianach.
*/

CREATE TRIGGER zaleznosciKierownicze
ON dbo.pracownicy
INSTEAD OF DELETE
AS
BEGIN
	DECLARE @id INT
		   ,@id_kierownika INT;
	SET @id = (SELECT
			d.id_pracownika
		FROM DELETED d);
	SET @id_kierownika = (SELECT
			d.id_kierownika
		FROM DELETED d);
	DECLARE @id_pracownika_kursor INT
		   ,@imie VARCHAR(50)
		   ,@nazwisko VARCHAR(50);
	DECLARE kursor CURSOR FOR (SELECT
			p.id_pracownika
		   ,p.imie
		   ,p.nazwisko
		FROM dbo.pracownicy p
		WHERE p.id_kierownika = @id);
	OPEN kursor;
	FETCH NEXT FROM kursor INTO @id_pracownika_kursor, @imie, @nazwisko;
	WHILE @@fetch_status = 0
	BEGIN
	UPDATE dbo.pracownicy
	SET dbo.pracownicy.id_kierownika = @id_kierownika
	WHERE dbo.pracownicy.id_pracownika = @id_pracownika_kursor;
	PRINT 'Zmieniono kierownika dla pracowniku o id ' + CAST(@id_pracownika_kursor AS VARCHAR(10)) + ' - ' + @imie + ' ' + @nazwisko;
	FETCH NEXT FROM kursor INTO @id_pracownika_kursor, @imie, @nazwisko;
	END;
	CLOSE kursor;
	DEALLOCATE kursor;
	DELETE dbo.pracownicy
	WHERE dbo.pracownicy.id_pracownika = @id;
END;
GO
DELETE dbo.pracownicy
WHERE dbo.pracownicy.id_pracownika = 13;
GO
SELECT
	*
FROM dbo.pracownicy p;

