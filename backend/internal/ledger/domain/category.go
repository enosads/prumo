package domain

import (
	"time"

	"github.com/google/uuid"
)

type CategoryKind string

const (
	CategoryKindIncome  CategoryKind = "income"
	CategoryKindExpense CategoryKind = "expense"
	CategoryKindBoth    CategoryKind = "both"
)

type Category struct {
	ID         uuid.UUID
	FamilyID   uuid.UUID
	Name       string
	Slug       *string
	Icon       *string
	Color      *string
	Kind       CategoryKind
	ParentID   *uuid.UUID
	SystemOnly bool
	CreatedAt  time.Time
}

type CanonicalRootCategory struct {
	Slug        string
	NamePTBR    string
	Icon        string
	Color       string
	Kind        CategoryKind
	SystemOnly  bool
	Description string
}

// CanonicalRootCategories define as 13 raízes semânticas globais + categoria de sistema (ADR-0002).
var CanonicalRootCategories = []CanonicalRootCategory{
	{
		Slug:        "housing",
		NamePTBR:    "Moradia",
		Icon:        "house.fill",
		Color:       "#007AFF",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Aluguel, condomínio, IPTU, reformas, manutenção",
	},
	{
		Slug:        "bills",
		NamePTBR:    "Contas & Assinaturas",
		Icon:        "play.tv.fill",
		Color:       "#5AC8FA",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Luz, água, gás, internet, streaming, planos recorrentes",
	},
	{
		Slug:        "food",
		NamePTBR:    "Alimentação & Mercado",
		Icon:        "cart.fill",
		Color:       "#FF9500",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Supermercado, feira, restaurantes, delivery, cafés",
	},
	{
		Slug:        "transport",
		NamePTBR:    "Transporte",
		Icon:        "car.fill",
		Color:       "#5856D6",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Combustível, transporte público, corrida por app, estacionamento",
	},
	{
		Slug:        "health",
		NamePTBR:    "Saúde & Farmácia",
		Icon:        "heart.fill",
		Color:       "#FF2D55",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Plano de saúde, consultas, farmácia, exames, terapia",
	},
	{
		Slug:        "education",
		NamePTBR:    "Educação",
		Icon:        "book.fill",
		Color:       "#34C759",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Mensalidade, cursos, livros técnicos, certificações",
	},
	{
		Slug:        "leisure",
		NamePTBR:    "Lazer & Viagens",
		Icon:        "gamecontroller.fill",
		Color:       "#AF52DE",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Cinema, shows, viagens, passeios, eventos, jogos",
	},
	{
		Slug:        "personal_care",
		NamePTBR:    "Cuidados Pessoais",
		Icon:        "sparkles",
		Color:       "#FF2D55",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Barbeiro, salão, academia, cosméticos, estética",
	},
	{
		Slug:        "shopping",
		NamePTBR:    "Compras & Roupas",
		Icon:        "bag.fill",
		Color:       "#FF9500",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Vestuário, eletrônicos, compras para o lar",
	},
	{
		Slug:        "giving",
		NamePTBR:    "Doações & Presentes",
		Icon:        "gift.fill",
		Color:       "#FF3B30",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Doações filantrópicas, presentes para terceiros",
	},
	{
		Slug:        "financial",
		NamePTBR:    "Taxas & Impostos",
		Icon:        "percent",
		Color:       "#8E8E93",
		Kind:        CategoryKindExpense,
		SystemOnly:  false,
		Description: "Tarifas bancárias, juros, DARF, impostos",
	},
	{
		Slug:        "income",
		NamePTBR:    "Receitas & Salário",
		Icon:        "banknote.fill",
		Color:       "#34C759",
		Kind:        CategoryKindIncome,
		SystemOnly:  false,
		Description: "Salário, freelance, rendimentos, reembolsos",
	},
	{
		Slug:        "transfer",
		NamePTBR:    "Transferências",
		Icon:        "arrow.left.arrow.right",
		Color:       "#007AFF",
		Kind:        CategoryKindBoth,
		SystemOnly:  false,
		Description: "Movimentações entre contas do mesmo núcleo familiar",
	},
	{
		Slug:        "uncategorized",
		NamePTBR:    "Não Categorizado",
		Icon:        "questionmark.circle.fill",
		Color:       "#8E8E93",
		Kind:        CategoryKindBoth,
		SystemOnly:  true,
		Description: "Inbox transitório de OCR/IA para revisão humana",
	},
}
